// SPDX-License-Identifier: MIT
// Thanks to ultrasecr.eth
pragma solidity ^0.8.19;

import { IPool } from "./interfaces/IPool.sol";
import { IPoolDataProvider } from "./interfaces/IPoolDataProvider.sol";
import { IFlashLoanReceiverV2V3 } from "./interfaces/IFlashLoanReceiverV2V3.sol";

import { FixedPointMathLib } from "lib/solmate/src/utils/FixedPointMathLib.sol";

import { BaseWrapper, IERC7399, ERC20 } from "../BaseWrapper.sol";
import { Arrays } from "../utils/Arrays.sol";

/// @dev Aave Flash Lender that uses the Aave Pool as source of liquidity.
/// Aave doesn't allow flow splitting or pushing repayments, so this wrapper is completely vanilla.
contract AaveWrapper is BaseWrapper, IFlashLoanReceiverV2V3 {
    using FixedPointMathLib for uint256;
    using Arrays for *;

    error NotPool();
    error NotInitiator();

    // solhint-disable-next-line var-name-mixedcase
    address public immutable ADDRESSES_PROVIDER;
    // solhint-disable-next-line var-name-mixedcase
    address public immutable POOL;
    // solhint-disable-next-line var-name-mixedcase
    address public immutable LENDING_POOL;

    IPoolDataProvider public immutable dataProvider;
    bool public immutable isV2;

    constructor(address _pool, address _addressesProvider, IPoolDataProvider _dataProvider, bool _isV2) {
        POOL = _pool;
        ADDRESSES_PROVIDER = _addressesProvider;
        LENDING_POOL = address(_pool);
        dataProvider = _dataProvider;
        isV2 = _isV2;
    }

    /// @inheritdoc IERC7399
    function maxFlashLoan(address asset) external view returns (uint256) {
        return _maxFlashLoan(asset);
    }

    /// @inheritdoc IERC7399
    function flashFee(address asset, uint256 amount) external view returns (uint256) {
        uint256 max = _maxFlashLoan(asset);
        require(max > 0, "Unsupported currency");
        return amount >= max ? type(uint256).max : _flashFee(amount);
    }

    /// @inheritdoc IFlashLoanReceiverV2V3
    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata fees,
        address initiator,
        bytes calldata params
    )
        external
        override
        returns (bool)
    {
        if (msg.sender != address(POOL)) revert NotPool();
        if (initiator != address(this)) revert NotInitiator();

        _bridgeToCallback(assets[0], amounts[0], fees[0], params);

        return true;
    }

    function _flashLoan(address asset, uint256 amount, bytes memory data) internal override {
        IPool(POOL).flashLoan({
            receiverAddress: address(this),
            assets: asset.toArray(),
            amounts: amount.toArray(),
            interestRateModes: 0.toArray(), // NONE
            onBehalfOf: address(this),
            params: data,
            referralCode: 0
        });
    }

    function _maxFlashLoan(address asset) internal view returns (uint256 max) {
        (,,,,,,,, bool isActive, bool isFrozen) = dataProvider.getReserveConfigurationData(asset);
        (address aTokenAddress,,) = dataProvider.getReserveTokensAddresses(asset);
        bool isFlashLoanEnabled = isV2 ? true : dataProvider.getFlashLoanEnabled(asset);

        max = !isFrozen && isActive && isFlashLoanEnabled ? ERC20(asset).balanceOf(aTokenAddress) : 0;
    }

    function _flashFee(uint256 amount) internal view returns (uint256) {
        return amount.mulWadUp(IPool(POOL).FLASHLOAN_PREMIUM_TOTAL() * 0.0001e18);
    }
}
