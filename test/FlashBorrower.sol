// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC7399 } from "lib/erc7399/src/interfaces/IERC7399.sol";
import { IERC20 } from "lib/erc7399/src/interfaces/IERC20.sol";

contract LoanReceiver {
    function retrieve(IERC20 asset) external {
        asset.transfer(msg.sender, asset.balanceOf(address(this)));
    }
}

contract FlashBorrower {
    bytes32 public constant ERC7399_CALLBACK_SUCCESS = keccak256("ERC7399_CALLBACK_SUCCESS");
    IERC7399 lender;
    LoanReceiver loanReceiver;

    uint256 public flashBalance;
    address public flashInitiator;
    IERC20 public flashAsset;
    uint256 public flashAmount;
    uint256 public flashFee;

    constructor(IERC7399 lender_) {
        lender = lender_;
        loanReceiver = new LoanReceiver();
    }

    /// @dev ERC-3156++ Flash loan callback
    function onFlashLoan(
        address initiator,
        address paymentReceiver,
        IERC20 asset,
        uint256 amount,
        uint256 fee,
        bytes calldata
    )
        external
        returns (bytes memory)
    {
        require(msg.sender == address(lender), "FlashBorrower: Untrusted lender");
        require(initiator == address(this), "FlashBorrower: External loan initiator");

        flashInitiator = initiator;
        flashAsset = asset;
        flashAmount = amount;
        flashFee = fee;
        loanReceiver.retrieve(asset);
        flashBalance = IERC20(asset).balanceOf(address(this));
        asset.transfer(paymentReceiver, amount + fee);

        return abi.encode(ERC7399_CALLBACK_SUCCESS);
    }

    function onSteal(
        address initiator,
        address,
        IERC20 asset,
        uint256 amount,
        uint256 fee,
        bytes calldata
    )
        external
        returns (bytes memory)
    {
        require(msg.sender == address(lender), "FlashBorrower: Untrusted lender");
        require(initiator == address(this), "FlashBorrower: External loan initiator");
        flashInitiator = initiator;
        flashAsset = asset;
        flashAmount = amount;
        flashFee = fee;

        // do nothing

        return abi.encode(ERC7399_CALLBACK_SUCCESS);
    }

    function onReenter(
        address initiator,
        address paymentReceiver,
        IERC20 asset,
        uint256 amount,
        uint256 fee,
        bytes calldata
    )
        external
        returns (bytes memory)
    {
        require(msg.sender == address(lender), "FlashBorrower: Untrusted lender");
        require(initiator == address(this), "FlashBorrower: External loan initiator");
        flashInitiator = initiator;
        flashAsset = asset;
        loanReceiver.retrieve(asset);

        flashBorrow(asset, amount * 2);

        asset.transfer(paymentReceiver, amount + fee);

        // flashBorrow will have initialized these
        flashAmount += amount;
        flashFee += fee;

        return abi.encode(ERC7399_CALLBACK_SUCCESS);
    }

    function onFlashLoanVoid(
        address initiator,
        address paymentReceiver,
        IERC20 asset,
        uint256 amount,
        uint256 fee,
        bytes calldata
    )
        external
        returns (bytes memory)
    {
        require(msg.sender == address(lender), "FlashBorrower: Untrusted lender");
        require(initiator == address(this), "FlashBorrower: External loan initiator");

        flashInitiator = initiator;
        flashAsset = asset;
        flashAmount = amount;
        flashFee = fee;
        loanReceiver.retrieve(asset);
        flashBalance = IERC20(asset).balanceOf(address(this));
        asset.transfer(paymentReceiver, amount + fee);

        return "";
    }

    function flashBorrow(IERC20 asset, uint256 amount) public returns (bytes memory) {
        return lender.flash(address(loanReceiver), asset, amount, "", this.onFlashLoan);
    }

    function flashBorrowAndSteal(IERC20 asset, uint256 amount) public returns (bytes memory) {
        return lender.flash(address(loanReceiver), asset, amount, "", this.onSteal);
    }

    function flashBorrowAndReenter(IERC20 asset, uint256 amount) public returns (bytes memory) {
        return lender.flash(address(loanReceiver), asset, amount, "", this.onReenter);
    }

    function flashBorrowVoid(IERC20 asset, uint256 amount) public returns (bytes memory) {
        return lender.flash(address(loanReceiver), asset, amount, "", this.onFlashLoanVoid);
    }
}
