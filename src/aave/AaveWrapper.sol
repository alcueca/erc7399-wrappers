// SPDX-License-Identifier: GPL-3.0-or-later
// Thanks to ultrasecr.eth
pragma solidity ^0.8.0;

import { IPool } from "./interfaces/IPool.sol";
import { DataTypes } from "./interfaces/DataTypes.sol";
import { ReserveConfiguration } from "./interfaces/ReserveConfiguration.sol";
import { IPoolAddressesProvider } from "./interfaces/IPoolAddressesProvider.sol";
import { IFlashLoanSimpleReceiver } from "./interfaces/IFlashLoanSimpleReceiver.sol";

import { TransferHelper } from "../utils/TransferHelper.sol";

import { IERC20 } from "lib/erc3156pp/src/interfaces/IERC20.sol";
import { FixedPointMathLib } from "lib/solmate/src/utils/FixedPointMathLib.sol";
import { IERC3156PPFlashLender } from "lib/erc3156pp/src/interfaces/IERC3156PPFlashLender.sol";

contract AaveWrapper is IERC3156PPFlashLender, IFlashLoanSimpleReceiver {
    using TransferHelper for IERC20;
    using FixedPointMathLib for uint256;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

    struct Data {
        address loanReceiver;
        address initiator;
        function(address, address, IERC20, uint256, uint256, bytes memory) external returns (bytes memory) callback;
        bytes initiatorData;
    }

    IPoolAddressesProvider public immutable ADDRESSES_PROVIDER;
    IPool public POOL;

    bytes internal _callbackResult;

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

    /// @dev Use the aggregator to serve an ERC3156++ flash loan.
    /// @dev Forward the callback to the callback receiver. The borrower only needs to trust the aggregator and its
    /// governance, instead of the underlying lenders.
    /// @param loanReceiver The address receiving the flash loan
    /// @param asset The asset to be loaned
    /// @param amount The amount to loaned
    /// @param initiatorData The ABI encoded initiator data
    /// @param callback The address and signature of the callback function
    /// @return result ABI encoded result of the callback
    function flashLoan(
        address loanReceiver,
        IERC20 asset,
        uint256 amount,
        bytes calldata initiatorData,
        /// @dev callback.
        /// This is a concatenation of (address, bytes4), where the address is the callback receiver, and the bytes4 is
        /// the signature of callback function.
        /// The arguments in the callback function are fixed.
        /// If the callback receiver needs to know the loan receiver, it should be encoded by the initiator in `data`.
        /// @param initiator The address that called this function
        /// @param paymentReceiver The address that needs to receive the amount plus fee at the end of the callback
        /// @param asset The asset to be loaned
        /// @param amount The amount to loaned
        /// @param fee The fee to be paid
        /// @param data The ABI encoded data to be passed to the callback
        /// @return result ABI encoded result of the callback
        function(address, address, IERC20, uint256, uint256, bytes memory) external returns (bytes memory) callback
    )
        external
        returns (bytes memory result)
    {
        Data memory data = Data({
            loanReceiver: loanReceiver,
            initiator: msg.sender,
            callback: callback,
            initiatorData: initiatorData
        });

        POOL.flashLoanSimple({
            receiverAddress: address(this),
            asset: address(asset),
            amount: amount,
            params: abi.encode(data),
            referralCode: 0
        });

        result = _callbackResult;
        // Avoid storage write if not needed
        if (result.length > 0) {
            delete _callbackResult;
        }
        return result;
    }

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 fee,
        address aaveInitiator,
        bytes calldata params
    )
        external
        override
        returns (bool)
    {
        require(msg.sender == address(POOL), "not pool");
        require(aaveInitiator == address(this), "AaveFlashLoanProvider: not initiator");

        Data memory data = abi.decode(params, (Data));
        IERC20(asset).approve(address(POOL), amount + fee);
        IERC20(asset).safeTransfer(data.loanReceiver, amount);

        // call the callback and tell the callback receiver to repay the loan to this contract
        bytes memory result = data.callback(data.initiator, address(this), IERC20(asset), amount, fee, data.initiatorData);

        if (result.length > 0) {
            // if there's any result, it is kept in a storage variable to be retrieved later in this tx
            _callbackResult = result;
        }

        return true;
    }
}
