// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC3156FlashLender } from "lib/erc3156/contracts/interfaces/IERC3156FlashLender.sol";
import { IERC3156FlashBorrower } from "lib/erc3156/contracts/interfaces/IERC3156FlashBorrower.sol";
import { RevertMsgExtractor } from "../utils/RevertMsgExtractor.sol";
import { FunctionCodec } from "../utils/FunctionCodec.sol";

import { IERC3156PPFlashLender } from "lib/erc3156pp/src/interfaces/IERC3156PPFlashLender.sol";
import { IERC20 } from "lib/erc3156pp/src/interfaces/IERC20.sol";


library TransferHelper {
    /// @notice Transfers assets from msg.sender to a recipient
    /// @dev Errors with the underlying revert message if transfer fails
    /// @param asset The contract address of the asset which will be transferred
    /// @param to The recipient of the transfer
    /// @param value The value of the transfer
    function safeTransfer(
        IERC20 asset,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = address(asset).call(abi.encodeWithSelector(IERC20.transfer.selector, to, value));
        if (!(success && (data.length == 0 || abi.decode(data, (bool))))) revert(RevertMsgExtractor.getRevertMsg(data));
    }
}

/**
 * @author Alberto Cuesta Cañada
 * @dev ERC3156++ Flash Lender that uses ERC3156 Flash Lenders as source of liquidity.
 */
contract ERC3156Wrapper is IERC3156PPFlashLender, IERC3156FlashBorrower {
    using TransferHelper for IERC20;
    using RevertMsgExtractor for bytes;
    using FunctionCodec for function(address, address, IERC20, uint256, uint256, bytes memory) external returns (bytes memory);
    using FunctionCodec for bytes24;

    bytes32 public constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");

    mapping(IERC20 => IERC3156FlashLender) public lenders;
    bytes internal _callbackResult;

    /**
     * @param assets_ Asset contracts supported for flash lending.
     * @param lenders_ The flash lenders that will be used for each asset.
     */
    constructor(
        IERC20[] memory assets_,
        IERC3156FlashLender[] memory lenders_
    ) {
        require (assets_.length == lenders_.length, "Arrays must be the same length");
        for (uint256 i = 0; i < assets_.length; i++) {
            lenders[assets_[i]] = IERC3156FlashLender(address(lenders_[i]));
        }
    }

    /// @dev The fee to be charged for a given loan.
    /// @param asset The loan currency.
    /// @param amount The amount of assets lent.
    /// @return The amount of `asset` to be charged for the loan, on top of the returned principal. Returns type(uint256).max if the loan is not possible.
    function flashFee(
        IERC20 asset,
        uint256 amount
    ) external view returns (uint256) {
        IERC3156FlashLender lender = lenders[asset];
        require (address(lender) != address(0), "Unsupported currency");
        if (lender.maxFlashLoan(address(asset)) < amount) return type(uint256).max; 
        else return lender.flashFee(address(asset), amount);
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
    ) external returns (bytes memory) {
        IERC3156FlashLender lender = lenders[asset];
        require (address(lender) != address(0), "Unsupported currency");

        bytes memory data = abi.encode(msg.sender, loanReceiver, callback.encodeFunction(), initiatorData);

        // We get funds from an ERC3156 lender to serve the ERC3156++ flash loan in our ERC3156 callback
        lender.flashLoan(this, address(asset), amount, data);

        bytes memory result = _callbackResult;
        _callbackResult = ""; // TODO: Confirm that this deletes the storage variable
        return result;
    }

    /**
     * @dev Receive a flash loan.
     * @param initiator The initiator of the loan.
     * @param asset The loan currency.
     * @param amount The amount of assets lent.
     * @param fee The additional amount of assets to repay.
     * @param data Arbitrary data structure, intended to contain initiator-defined parameters.
     * @return The keccak256 hash of "ERC3156FlashBorrower.onFlashLoan"
     */
    function onFlashLoan(
        address initiator,
        address asset,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32) {
        require(initiator == address(this), "FlashMinter: External loan initiator");
        require(msg.sender == address(lenders[IERC20(asset)]), "Unknown lender");
        IERC3156FlashLender lender = IERC3156FlashLender(msg.sender);

        // We pass the loan to the loan receiver and we store the callback result in storage for the the ERC3156++ flashLoan function to recover it.
        _callbackResult = _callFromData(IERC20(asset), amount, fee, data);

        IERC20(asset).approve(address(lender), amount + fee);

        return CALLBACK_SUCCESS;
    }

    /// @dev Internal function to transfer to the loan receiver and the callback. It is used to avoid stack too deep.
    function _callFromData(IERC20 asset, uint256 amount, uint256 fee, bytes memory data) internal returns(bytes memory) {
        (address initiator, address loanReceiver, bytes24 encodedCallback, bytes memory initiatorData) = 
            abi.decode(data, (address, address, bytes24, bytes));

        function(address, address, IERC20, uint256, uint256, bytes memory) external returns (bytes memory) callback = encodedCallback.decodeFunction();

        // We pass the loan to the loan receiver
        IERC20(asset).safeTransfer(loanReceiver, amount);

        // We call the callback
        return callback(initiator, address(this), asset, amount, fee, initiatorData);
    }
}