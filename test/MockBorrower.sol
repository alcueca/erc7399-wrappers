// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "erc7399/IERC7399.sol";
import "src/BaseWrapper.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";

contract LoanReceiver {
    function retrieve(address asset) external {
        ERC20(asset).transfer(msg.sender, ERC20(asset).balanceOf(address(this)));
    }
}

/// @dev Mock flash loan borrower. It allows to examine the state of the borrower during the callback.
contract MockBorrower {
    bytes32 public constant ERC3156PP_CALLBACK_SUCCESS = keccak256("ERC3156PP_CALLBACK_SUCCESS");
    IERC7399 lender;
    LoanReceiver loanReceiver;

    uint256 public flashBalance;
    address public flashInitiator;
    address public flashAsset;
    uint256 public flashAmount;
    uint256 public flashFee;

    constructor(IERC7399 lender_) {
        lender = lender_;
        loanReceiver = new LoanReceiver();
    }

    /// @dev Flash loan callback
    function onFlashLoan(
        address initiator,
        address paymentReceiver,
        address asset,
        uint256 amount,
        uint256 fee,
        bytes calldata
    )
        external
        returns (bytes memory)
    {
        require(msg.sender == address(lender), "MockBorrower: Untrusted lender");
        require(initiator == address(this), "MockBorrower: External loan initiator");

        flashInitiator = initiator;
        flashAsset = asset;
        flashAmount = amount;
        flashFee = fee;
        loanReceiver.retrieve(asset);
        flashBalance = ERC20(asset).balanceOf(address(this));
        ERC20(asset).transfer(paymentReceiver, amount + fee);

        return abi.encode(ERC3156PP_CALLBACK_SUCCESS);
    }

    function onSteal(
        address initiator,
        address,
        address asset,
        uint256 amount,
        uint256 fee,
        bytes calldata
    )
        external
        returns (bytes memory)
    {
        require(msg.sender == address(lender), "MockBorrower: Untrusted lender");
        require(initiator == address(this), "MockBorrower: External loan initiator");
        flashInitiator = initiator;
        flashAsset = asset;
        flashAmount = amount;
        flashFee = fee;

        // do nothing

        return abi.encode(ERC3156PP_CALLBACK_SUCCESS);
    }

    function onReenter(
        address initiator,
        address paymentReceiver,
        address asset,
        uint256 amount,
        uint256 fee,
        bytes calldata
    )
        external
        returns (bytes memory)
    {
        require(msg.sender == address(lender), "MockBorrower: Untrusted lender");
        require(initiator == address(this), "MockBorrower: External loan initiator");
        flashInitiator = initiator;
        flashAsset = asset;
        loanReceiver.retrieve(asset);

        flashBorrow(asset, amount * 2);

        ERC20(asset).transfer(paymentReceiver, amount + fee);

        // flashBorrow will have initialized these
        flashAmount += amount;
        flashFee += fee;

        return abi.encode(ERC3156PP_CALLBACK_SUCCESS);
    }

    function onFlashLoanVoid(
        address initiator,
        address paymentReceiver,
        address asset,
        uint256 amount,
        uint256 fee,
        bytes calldata
    )
        external
        returns (bytes memory)
    {
        require(msg.sender == address(lender), "MockBorrower: Untrusted lender");
        require(initiator == address(this), "MockBorrower: External loan initiator");

        flashInitiator = initiator;
        flashAsset = asset;
        flashAmount = amount;
        flashFee = fee;
        loanReceiver.retrieve(asset);
        flashBalance = ERC20(asset).balanceOf(address(this));
        ERC20(asset).transfer(paymentReceiver, amount + fee);

        return "";
    }

    function flashBorrow(address asset, uint256 amount) public returns (bytes memory) {
        return lender.flash(address(loanReceiver), asset, amount, "", this.onFlashLoan);
    }

    function flashBorrowNoPointers(address asset, uint256 amount) public returns (bytes memory) {
        return BaseWrapper(address(lender)).flash(
            address(loanReceiver), asset, amount, "", address(this), this.onFlashLoan.selector
        );
    }

    function flashBorrowAndSteal(address asset, uint256 amount) public returns (bytes memory) {
        return lender.flash(address(loanReceiver), asset, amount, "", this.onSteal);
    }

    function flashBorrowAndReenter(address asset, uint256 amount) public returns (bytes memory) {
        return lender.flash(address(loanReceiver), asset, amount, "", this.onReenter);
    }

    function flashBorrowVoid(address asset, uint256 amount) public returns (bytes memory) {
        return lender.flash(address(loanReceiver), asset, amount, "", this.onFlashLoanVoid);
    }
}
