// SPDX-License-Identifier: MIT
// Thanks to ultrasecr.eth
pragma solidity ^0.8.0;

import { IPool } from "./interfaces/IPool.sol";
import { DataTypes } from "./interfaces/DataTypes.sol";
import { ReserveConfiguration } from "./interfaces/ReserveConfiguration.sol";
import { IPoolAddressesProvider } from "./interfaces/IPoolAddressesProvider.sol";
import { IFlashLoanSimpleReceiver } from "./interfaces/IFlashLoanSimpleReceiver.sol";

import { IERC20 } from "lib/erc3156pp/src/interfaces/IERC20.sol";
import { FixedPointMathLib } from "lib/solmate/src/utils/FixedPointMathLib.sol";

import { BaseWrapper } from "../BaseWrapper.sol";

contract AaveWrapper is BaseWrapper, IFlashLoanSimpleReceiver {
    using FixedPointMathLib for uint256;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

    IPoolAddressesProvider public immutable ADDRESSES_PROVIDER;
    IPool public immutable POOL;

    constructor(IPoolAddressesProvider provider) {
        ADDRESSES_PROVIDER = provider;
        POOL = IPool(provider.getPool());
    }

    /**
     * @dev From ERC-3156. The fee to be charged for a given loan.
     * @param asset The loan currency.
     * @param amount The amount of assets lent.
     * @return feeAmount The amount of `asset` to be charged for the loan, on top of the returned principal.
     * type(uint256).max if the loan is not possible.
     */
    function flashFee(IERC20 asset, uint256 amount) external view returns (uint256 feeAmount) {
        feeAmount = amount < liquidity(asset) ? amount.mulWadUp(fee()) : type(uint256).max;
    }

    function fee() public view returns (uint256) {
        return POOL.FLASHLOAN_PREMIUM_TOTAL() * 0.0001e18;
    }

    function liquidity(IERC20 asset) public view returns (uint256 liquidity_) {
        DataTypes.ReserveData memory reserve = POOL.getReserveData(address(asset));
        DataTypes.ReserveConfigurationMap memory configuration = reserve.configuration;
        liquidity_ = (!configuration.getPaused() && configuration.getActive() && configuration.getFlashLoanEnabled())
            ? asset.balanceOf(reserve.aTokenAddress)
            : 0;
    }

    function _flashLoan(IERC20 asset, uint256 amount, bytes memory data) internal override {
        POOL.flashLoanSimple({
            receiverAddress: address(this),
            asset: address(asset),
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
        require(msg.sender == address(POOL), "AaveFlashLoanProvider: not pool");
        require(initiator == address(this), "AaveFlashLoanProvider: not initiator");

        bridgeToCallback(IERC20(asset), amount, fee, params);

        return true;
    }
}
