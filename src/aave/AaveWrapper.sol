// SPDX-License-Identifier: GPL-3.0-or-later
// Thanks to ultrasecr.eth
pragma solidity ^0.8.0;

import { IPool } from "./interfaces/IPool.sol";
import { DataTypes } from "./interfaces/DataTypes.sol";
import { ReserveConfiguration } from "./interfaces/ReserveConfiguration.sol";
import { IPoolAddressesProvider } from "./interfaces/IPoolAddressesProvider.sol";
import { IFlashLoanSimpleReceiver } from "./interfaces/IFlashLoanSimpleReceiver.sol";

import { FunctionCodec } from "../utils/FunctionCodec.sol";
import { TransferHelper } from "../utils/TransferHelper.sol";

import { IERC20 } from "lib/erc3156pp/src/interfaces/IERC20.sol";
import { FixedPointMathLib } from "lib/solmate/src/utils/FixedPointMathLib.sol";
import { IERC3156PPFlashLender } from "lib/erc3156pp/src/interfaces/IERC3156PPFlashLender.sol";

import { console2 } from "forge-std/console2.sol";

contract AaveWrapper is IERC3156PPFlashLender, IFlashLoanSimpleReceiver {
    using TransferHelper for IERC20;
    using FunctionCodec for function(address, address, IERC20, uint256, uint256, bytes memory) external returns (bytes memory);
    using FunctionCodec for bytes24;
    using FixedPointMathLib for uint256;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

    bytes internal _callbackResult;
    IPoolAddressesProvider public immutable ADDRESSES_PROVIDER;
    IPool public POOL;

    constructor(IPoolAddressesProvider provider) {
        ADDRESSES_PROVIDER = provider;
        POOL = IPool(provider.getPool());
    }

    function updatePool() external {
        POOL = IPool(ADDRESSES_PROVIDER.getPool());
    }

    function flashFee(IERC20 asset, uint256 amount)
        external
        view
        returns (uint256 fee)
    {
        DataTypes.ReserveData memory reserve = POOL.getReserveData(address(asset));
        DataTypes.ReserveConfigurationMap memory configuration = reserve.configuration;

        if (!configuration.getPaused() && 
            configuration.getActive() &&
            configuration.getFlashLoanEnabled() &&
            amount < asset.balanceOf(reserve.aTokenAddress)
        ) fee = amount.mulWadUp(POOL.FLASHLOAN_PREMIUM_TOTAL() * 0.0001e18);
        else fee = type(uint256).max;
    }

    /// @dev Use the aggregator to serve an ERC3156++ flash loan.
    /// @dev Forward the callback to the callback receiver. The borrower only needs to trust the aggregator and its governance, instead of the underlying lenders.
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
        /// This is a concatenation of (address, bytes4), where the address is the callback receiver, and the bytes4 is the signature of callback function.
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
    ) external returns (bytes memory result) {
        bytes memory data = abi.encode(msg.sender, loanReceiver, callback.encodeFunction(), initiatorData);

        POOL.flashLoanSimple({
            receiverAddress: address(this),
            asset: address(asset),
            amount: amount,
            params: data,
            referralCode: 0
        });

        result = _callbackResult;
        delete _callbackResult;
        return result;
    }

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 fee,
        address aaveInitiator,
        bytes calldata data
    ) external override returns (bool) {
        console2.log("executeOperation");
        require(msg.sender == address(POOL), "not pool");
        require(aaveInitiator == address(this), "AaveFlashLoanProvider: not initiator");

        address initiator;
        bytes memory initiatorData;
        function(address, address, IERC20, uint256, uint256, bytes memory) external returns (bytes memory) callback;
        {
            address loanReceiver;
            bytes24 encodedCallback;

            // decode data
            console2.log("abi decoding...");
            (initiator, loanReceiver, encodedCallback, initiatorData) = abi.decode(data, (address, address, bytes24, bytes));
            console2.log("callback decoding...");
            callback = encodedCallback.decodeFunction();

            IERC20(asset).approve(address(POOL), amount + fee);
            IERC20(asset).safeTransfer(loanReceiver, amount);
        } // release loanReceiver and encodedCallback from the stack


        // call the callback and tell the calback receiver to repay the loan to this contract
        // the callback result is kept in a storage variable to be retrieved later in this tx
        _callbackResult = callback(initiator, address(this), IERC20(asset), amount, fee, initiatorData); // TODO: Skip the storage write if result.length == 0

        return true;
    }
}