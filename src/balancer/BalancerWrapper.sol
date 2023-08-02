// SPDX-License-Identifier: MIT
// Thanks to ultrasecr.eth
pragma solidity ^0.8.0;

import { IFlashLoanRecipient } from "./interfaces/IFlashLoanRecipient.sol";
import { IFlashLoaner } from "./interfaces/IFlashLoaner.sol";

import { Arrays } from "../utils/Arrays.sol";

import { FixedPointMathLib } from "lib/solmate/src/utils/FixedPointMathLib.sol";
import { IERC20 } from "lib/erc7399/src/interfaces/IERC20.sol";

import { BaseWrapper } from "../BaseWrapper.sol";

contract BalancerWrapper is BaseWrapper, IFlashLoanRecipient {
    using Arrays for uint256;
    using Arrays for address;
    using FixedPointMathLib for uint256;

    IFlashLoaner public immutable balancer;

    bytes32 private flashLoanDataHash;

    constructor(IFlashLoaner _balancer) {
        balancer = _balancer;
    }

    /**
     * @dev From ERC-3156. The fee to be charged for a given loan.
     * @param asset The loan currency.
     * @param amount The amount of assets lent.
     * @return fee The amount of `asset` to be charged for the loan, on top of the returned principal.
     * type(uint256).max if the loan is not possible.
     */
    function flashFee(IERC20 asset, uint256 amount) external view returns (uint256 fee) {
        if (amount >= asset.balanceOf(address(balancer))) fee = type(uint256).max;
        else fee = amount.mulWadUp(balancer.getProtocolFeesCollector().getFlashLoanFeePercentage());
    }

    function _flashLoan(IERC20 asset, uint256 amount, bytes memory data) internal override {
        flashLoanDataHash = keccak256(data);
        balancer.flashLoan(this, address(asset).toArray(), amount.toArray(), data);
    }

    /// @inheritdoc IFlashLoanRecipient
    function receiveFlashLoan(
        address[] memory assets,
        uint256[] memory amounts,
        uint256[] memory fees,
        bytes memory params
    )
        external
        override
    {
        require(msg.sender == address(balancer), "BalancerWrapper: not balancer");
        require(keccak256(params) == flashLoanDataHash, "BalancerWrapper: params hash mismatch");
        delete flashLoanDataHash;

        bridgeToCallback(IERC20(assets[0]), amounts[0], fees[0], params);
    }

    function _repayTo() internal view override returns (address) {
        return address(balancer);
    }
}
