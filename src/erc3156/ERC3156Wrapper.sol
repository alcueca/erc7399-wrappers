// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IERC3156FlashLender } from "lib/erc3156/contracts/interfaces/IERC3156FlashLender.sol";
import { IERC3156FlashBorrower } from "lib/erc3156/contracts/interfaces/IERC3156FlashBorrower.sol";

import { BaseWrapper, IERC7399 } from "../BaseWrapper.sol";

/**
 * @author Alberto Cuesta Cañada
 * @dev ERC7399 Flash Lender that uses ERC3156 Flash Lenders as source of liquidity.
 * ERC3156 doesn't allow flow splitting or pushing repayments, so this wrapper is completely vanilla.
 */
contract ERC3156Wrapper is BaseWrapper, IERC3156FlashBorrower {
    bytes32 public constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");

    mapping(address asset => IERC3156FlashLender lender) public lenders;

    /**
     * @param assets_ Asset contracts supported for flash lending.
     * @param lenders_ The flash lenders that will be used for each asset.
     */
    constructor(address[] memory assets_, IERC3156FlashLender[] memory lenders_) {
        require(assets_.length == lenders_.length, "Arrays must be the same length");
        for (uint256 i = 0; i < assets_.length; i++) {
            lenders[assets_[i]] = IERC3156FlashLender(address(lenders_[i]));
        }
    }

    /// @inheritdoc IERC7399
    function maxFlashLoan(address asset) external view returns (uint256) {
        IERC3156FlashLender lender = lenders[asset];
        require(address(lender) != address(0), "Unsupported currency");
        return lender.maxFlashLoan(asset);
    }

    /// @inheritdoc IERC7399
    function flashFee(address asset, uint256 amount) external view returns (uint256) {
        IERC3156FlashLender lender = lenders[asset];
        require(address(lender) != address(0), "Unsupported currency");
        return lender.flashFee(asset, amount);
    }

    function _flashLoan(address asset, uint256 amount, bytes memory data) internal override {
        IERC3156FlashLender lender = lenders[asset];
        require(address(lender) != address(0), "Unsupported currency");

        // We get funds from an ERC3156 lender to serve the ERC7399 flash loan in our ERC3156 callback
        lender.flashLoan(this, address(asset), amount, data);
    }

    /// @inheritdoc IERC3156FlashBorrower
    function onFlashLoan(
        address erc3156initiator,
        address asset,
        uint256 amount,
        uint256 fee,
        bytes calldata params
    )
        external
        returns (bytes32)
    {
        require(erc3156initiator == address(this), "External loan initiator");
        require(msg.sender == address(lenders[asset]), "Unknown lender");

        bridgeToCallback(asset, amount, fee, params);

        return CALLBACK_SUCCESS;
    }
}
