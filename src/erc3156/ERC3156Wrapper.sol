// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC3156FlashLender } from "lib/erc3156/contracts/interfaces/IERC3156FlashLender.sol";
import { IERC3156FlashBorrower } from "lib/erc3156/contracts/interfaces/IERC3156FlashBorrower.sol";
import { RevertMsgExtractor } from "../utils/RevertMsgExtractor.sol";

import { IERC3156PPFlashLender } from "lib/erc3156pp/src/interfaces/IERC3156PPFlashLender.sol";
import { IERC20 } from "lib/erc3156pp/src/interfaces/IERC20.sol";

library TransferHelper {
    /// @notice Transfers tokens from msg.sender to a recipient
    /// @dev Errors with the underlying revert message if transfer fails
    /// @param token The contract address of the token which will be transferred
    /// @param to The recipient of the transfer
    /// @param value The value of the transfer
    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(IERC20.transfer.selector, to, value));
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

    bytes32 constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");

    mapping(IERC20 => IERC3156FlashLender) public lenders;
    bytes internal _callbackResult;

    /**
     * @param assets_ Asset contracts supported for flash lending.
     * @param lenders_ The flash lenders that will be used for each asset.
     */
    constructor(
        IERC20[] memory assets_,
        IERC20[] memory lenders_
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
    /// @param userData The ABI encoded user data
    /// @param callback The address and signature of the callback function
    /// @return result ABI encoded result of the callback
    function flashLoan(
        address loanReceiver,
        IERC20 asset,
        uint256 amount,
        bytes calldata userData,
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

        bytes memory data = abi.encode(msg.sender, loanReceiver, callback.address, callback.selector, userData);

        // We get funds from an ERC3156 lender to serve the ERC3156++ flash loan in our ERC3156 callback
        lender.flashLoan(this, address(asset), amount, data);

        return _callbackResult;
    }

    /**
     * @dev Receive a flash loan.
     * @param initiator The initiator of the loan.
     * @param token The loan currency.
     * @param amount The amount of tokens lent.
     * @param fee The additional amount of tokens to repay.
     * @param data Arbitrary data structure, intended to contain user-defined parameters.
     * @return The keccak256 hash of "ERC3156FlashBorrower.onFlashLoan"
     */
    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32) {
        require(initiator == address(this), "FlashMinter: External loan initiator");
        require(msg.sender == address(lenders[IERC20(token)]), "Unknown lender");
        IERC3156FlashLender lender = IERC3156FlashLender(msg.sender);

        // We pass the loan to the loan receiver
        bytes memory result = _callFromData(IERC20(token), amount, fee, data);

        // We store the callback result in storage for the the ERC3156++ flashLoan function to recover it.
        _callbackResult = result;

        IERC20(token).approve(address(lender), amount + fee);

        return CALLBACK_SUCCESS;
    }

    /// @dev Internal function to transfer to the loan receiver and the callback. It is used to avoid stack too deep.
    function _callFromData(IERC20 token, uint256 amount, uint256 fee, bytes memory data) internal returns(bytes memory) {
        (address user, address loanReceiver, address callbackReceiver, bytes4 callbackSelector, bytes memory userData) = 
            abi.decode(data, (address, address, address, bytes4, bytes));

        // We pass the loan to the loan receiver
        IERC20(token).safeTransfer(loanReceiver, amount);
        (bool success, bytes memory result) = callbackReceiver.call(abi.encodeWithSelector(
            callbackSelector,
            user, // initiator
            address(this), // paymentReceiver
            token, // asset
            amount, // amount
            fee, // fee
            userData // data
        ));
        require(success, RevertMsgExtractor.getRevertMsg(result));
        return result;
    }
}