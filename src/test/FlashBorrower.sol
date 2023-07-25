// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC3156PPFlashLender } from "lib/erc3156pp/src/interfaces/IERC3156PPFlashLender.sol";
import { IERC20 } from "lib/erc3156pp/src/interfaces/IERC20.sol";


contract LoanReceiver {
    function retrieve(IERC20 asset) external {
        asset.transfer(msg.sender, asset.balanceOf(address(this)));
    }
}

contract FlashBorrower {
    bytes32 public constant ERC3156PP_CALLBACK_SUCCESS = keccak256("ERC3156PP_CALLBACK_SUCCESS");
    IERC3156PPFlashLender lender;
    LoanReceiver loanReceiver;

    uint256 public flashBalance;
    address public flashInitiator;
    IERC20 public flashAsset;
    uint256 public flashAmount;
    uint256 public flashFee;

    constructor (IERC3156PPFlashLender lender_) {
        lender = lender_;
        loanReceiver = new LoanReceiver();
    }

    /// @dev ERC-3156++ Flash loan callback
    function onFlashLoan(address initiator, address paymentReceiver, IERC20 asset, uint256 amount, uint256 fee, bytes calldata) external returns(bytes memory) {
        require(msg.sender == address(lender), "FlashBorrower: Untrusted lender");
        require(initiator == address(this), "FlashBorrower: External loan initiator");

        flashInitiator = initiator;
        flashAsset = asset;
        flashAmount = amount;
        flashFee = fee;
        loanReceiver.retrieve(asset);
        flashBalance = IERC20(asset).balanceOf(address(this));
        asset.transfer(paymentReceiver, amount + fee);

        return abi.encode(ERC3156PP_CALLBACK_SUCCESS);
    }

    function onSteal(address initiator, address, IERC20 asset, uint256 amount, uint256 fee, bytes calldata) external returns(bytes memory) {
        require(msg.sender == address(lender), "FlashBorrower: Untrusted lender");
        require(initiator == address(this), "FlashBorrower: External loan initiator");
        flashInitiator = initiator;
        flashAsset = asset;
        flashAmount = amount;
        flashFee = fee;
        
        // do nothing

        return abi.encode(ERC3156PP_CALLBACK_SUCCESS);
    }

    function onReenter(address initiator, address paymentReceiver, IERC20 asset, uint256 amount, uint256 fee, bytes calldata) external returns(bytes memory) {
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

        return abi.encode(ERC3156PP_CALLBACK_SUCCESS);
    }

    function flashBorrow(IERC20 asset, uint256 amount) public returns(bytes memory) {
        return lender.flashLoan(address(loanReceiver), asset, amount, "", this.onFlashLoan);
    }

    function flashBorrowAndSteal(IERC20 asset, uint256 amount) public returns(bytes memory) {
        return lender.flashLoan(address(loanReceiver), asset, amount, "", this.onSteal);
    }

    function flashBorrowAndReenter(IERC20 asset, uint256 amount) public returns(bytes memory) {
        return lender.flashLoan(address(loanReceiver), asset, amount, "", this.onReenter);
    }
}
