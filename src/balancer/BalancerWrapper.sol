// SPDX-License-Identifier: GPL-3.0-or-later
// Thanks to ultrasecr.eth
pragma solidity ^0.8.0;

import { IProtocolFeesCollector } from "./interfaces/IProtocolFeesCollector.sol";
import { IFlashLoanRecipient } from "./interfaces/IFlashLoanRecipient.sol";
import { IFlashLoaner } from "./interfaces/IFlashLoaner.sol";

import { TransferHelper } from "../utils/TransferHelper.sol";
import { FunctionCodec } from "../utils/FunctionCodec.sol";
import { Arrays } from "../utils/Arrays.sol";

import { IERC3156PPFlashLender } from "lib/erc3156pp/src/interfaces/IERC3156PPFlashLender.sol";
import { FixedPointMathLib } from "lib/solmate/src/utils/FixedPointMathLib.sol";
import { IERC20 } from "lib/erc3156pp/src/interfaces/IERC20.sol";

contract BalancerWrapper is IFlashLoanRecipient, IERC3156PPFlashLender {
    using TransferHelper for IERC20;
    using
    FunctionCodec
    for function(address, address, IERC20, uint256, uint256, bytes memory) external returns (bytes memory);
    using FunctionCodec for bytes24;
    using Arrays for uint256;
    using Arrays for address;
    using FixedPointMathLib for uint256;

    bytes32 private flashLoanDataHash;
    bytes internal _callbackResult;

    IFlashLoaner public immutable balancer;

    constructor(IFlashLoaner _balancer) {
        balancer = _balancer;
    }

    function flashFee(IERC20 asset, uint256 amount) external view returns (uint256 fee) {
        if (amount >= asset.balanceOf(address(balancer))) fee = type(uint256).max;
        else fee = amount.mulWadUp(balancer.getProtocolFeesCollector().getFlashLoanFeePercentage());
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
        returns (bytes memory)
    {
        bytes memory data =
            abi.encode(msg.sender, loanReceiver, asset, amount, callback.encodeFunction(), initiatorData);

        flashLoanDataHash = keccak256(data);
        balancer.flashLoan(this, address(asset).toArray(), amount.toArray(), data);

        bytes memory result = _callbackResult;
        delete _callbackResult; // TODO: Confirm that this deletes the storage variable
        return result;
    }

    function receiveFlashLoan(
        address[] memory assets,
        uint256[] memory amounts,
        uint256[] memory fees,
        bytes memory data
    )
        external
        override
    {
        require(msg.sender == address(balancer), "not balancer");
        require(keccak256(data) == flashLoanDataHash, "params hash mismatch");
        delete flashLoanDataHash;

        // decode data
        (
            address initiator,
            address loanReceiver,
            IERC20 asset,
            uint256 amount,
            bytes24 encodedCallback,
            bytes memory initiatorData
        ) = abi.decode(data, (address, address, IERC20, uint256, bytes24, bytes));

        function(address, address, IERC20, uint256, uint256, bytes memory) external returns (bytes memory) callback =
            encodedCallback.decodeFunction();

        // send the borrowed amount to the loan receiver
        asset.safeTransfer(address(loanReceiver), amount);

        // call the callback and tell the calback receiver to pay to the balancer contract
        // the callback result is kept in a storage variable to be retrieved later in this tx
        _callbackResult = callback(initiator, msg.sender, IERC20(assets[0]), amounts[0], fees[0], initiatorData); // TODO:
            // Skip the storage write if result.length == 0
    }
}
