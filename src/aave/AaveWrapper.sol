// SPDX-License-Identifier: MIT
// Thanks to ultrasecr.eth
pragma solidity ^0.8.19;

import { IPool } from "./interfaces/IPool.sol";
import { DataTypes } from "./interfaces/DataTypes.sol";
import { ReserveConfiguration } from "./interfaces/ReserveConfiguration.sol";
import { IPoolAddressesProvider } from "./interfaces/IPoolAddressesProvider.sol";
import { IFlashLoanSimpleReceiver } from "./interfaces/IFlashLoanSimpleReceiver.sol";

import { FixedPointMathLib } from "lib/solmate/src/utils/FixedPointMathLib.sol";

import { BaseWrapper, IERC7399, ERC20 } from "../BaseWrapper.sol";

/// @dev Aave Flash Lender that uses the Aave Pool as source of liquidity.
/// Aave doesn't allow flow splitting or pushing repayments, so this wrapper is completely vanilla.
contract AaveWrapper is BaseWrapper, IFlashLoanSimpleReceiver {
    using FixedPointMathLib for uint256;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

    error NotPool();
    error NotInitiator();

    // solhint-disable-next-line var-name-mixedcase
    IPoolAddressesProvider public immutable ADDRESSES_PROVIDER;
    // solhint-disable-next-line var-name-mixedcase
    IPool public immutable POOL;

    constructor(IPoolAddressesProvider provider) {
        ADDRESSES_PROVIDER = provider;
        POOL = IPool(provider.getPool());
    }

    /// @inheritdoc IERC7399
    function maxFlashLoan(address asset) external view returns (uint256 max) {
        DataTypes.ReserveData memory reserve = POOL.getReserveData(asset);
        DataTypes.ReserveConfigurationMap memory configuration = reserve.configuration;

        max = !configuration.getPaused() && configuration.getActive() && configuration.getFlashLoanEnabled()
            ? ERC20(asset).balanceOf(reserve.aTokenAddress)
            : 0;
    }

    /// @inheritdoc IERC7399
    function flashFee(address, uint256 amount) external view returns (uint256) {
        return amount.mulWadUp(POOL.FLASHLOAN_PREMIUM_TOTAL() * 0.0001e18);
    }

    function _flashLoan(address asset, uint256 amount, bytes memory data) internal override {
        POOL.flashLoanSimple({
            receiverAddress: address(this),
            asset: asset,
            amount: amount,
            params: data,
            referralCode: 0
        });
    }

    /// @inheritdoc IFlashLoanSimpleReceiver
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 fee,
        address initiator,
        bytes calldata params
    )
        external
        override
        returns (bool)
    {
        if (msg.sender != address(POOL)) revert NotPool();
        if (initiator != address(this)) revert NotInitiator();

        bridgeToCallback(asset, amount, fee, params);

        return true;
    }
}
