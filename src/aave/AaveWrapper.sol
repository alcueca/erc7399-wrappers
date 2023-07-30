// SPDX-License-Identifier: GPL-3.0-or-later
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
    IPool public POOL;

    constructor(IPoolAddressesProvider provider) {
        ADDRESSES_PROVIDER = provider;
        POOL = IPool(provider.getPool());
    }

    function updatePool() external {
        POOL = IPool(ADDRESSES_PROVIDER.getPool());
    }

    function flashFee(IERC20 asset, uint256 amount) external view returns (uint256 fee) {
        DataTypes.ReserveData memory reserve = POOL.getReserveData(address(asset));
        DataTypes.ReserveConfigurationMap memory configuration = reserve.configuration;

        if (
            !configuration.getPaused() && configuration.getActive() && configuration.getFlashLoanEnabled()
                && amount < asset.balanceOf(reserve.aTokenAddress)
        ) fee = amount.mulWadUp(POOL.FLASHLOAN_PREMIUM_TOTAL() * 0.0001e18);
        else fee = type(uint256).max;
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
        require(msg.sender == address(POOL), "not pool");
        require(initiator == address(this), "AaveFlashLoanProvider: not initiator");

        _handleFlashLoan(IERC20(asset), amount, fee, params);

        return true;
    }
}
