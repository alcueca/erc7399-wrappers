// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC3156FlashLender } from "lib/erc3156/contracts/interfaces/IERC3156FlashLender.sol";
import { IERC3156FlashBorrower } from "lib/erc3156/contracts/interfaces/IERC3156FlashBorrower.sol";

import { IERC20 } from "lib/erc7399/src/interfaces/IERC20.sol";

import { BaseWrapper } from "../BaseWrapper.sol";

/**
 * @author Alberto Cuesta Cañada
 * @dev ERC3156++ Flash Lender that uses ERC3156 Flash Lenders as source of liquidity.
 */
contract ERC3156Wrapper is BaseWrapper, IERC3156FlashBorrower {
    bytes32 public constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");

    mapping(IERC20 => IERC3156FlashLender) public lenders;

    /**
     * @param assets_ Asset contracts supported for flash lending.
     * @param lenders_ The flash lenders that will be used for each asset.
     */
    constructor(IERC20[] memory assets_, IERC3156FlashLender[] memory lenders_) {
        require(assets_.length == lenders_.length, "Arrays must be the same length");
        for (uint256 i = 0; i < assets_.length; i++) {
            lenders[assets_[i]] = IERC3156FlashLender(address(lenders_[i]));
        }
    }

    /**
     * @dev From ERC-3156. The fee to be charged for a given loan.
     * @param asset The loan currency.
     * @param amount The amount of assets lent.
     * @return The amount of `asset` to be charged for the loan, on top of the returned principal.
     * type(uint256).max if the loan is not possible.
     */
    function flashFee(IERC20 asset, uint256 amount) external view returns (uint256) {
        IERC3156FlashLender lender = lenders[asset];
        require(address(lender) != address(0), "Unsupported currency");
        if (lender.maxFlashLoan(address(asset)) < amount) return type(uint256).max;
        else return lender.flashFee(address(asset), amount);
    }

    function _flashLoan(IERC20 asset, uint256 amount, bytes memory data) internal override {
        IERC3156FlashLender lender = lenders[asset];
        require(address(lender) != address(0), "Unsupported currency");

        // We get funds from an ERC3156 lender to serve the ERC3156++ flash loan in our ERC3156 callback
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
        require(msg.sender == address(lenders[IERC20(asset)]), "Unknown lender");

        bridgeToCallback(IERC20(asset), amount, fee, params);

        return CALLBACK_SUCCESS;
    }
}
