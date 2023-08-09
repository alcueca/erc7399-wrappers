// SPDX-License-Identifier: MIT
// Thanks to ultrasecr.eth
pragma solidity ^0.8.0;

import { IFlashLoanRecipient } from "./interfaces/IFlashLoanRecipient.sol";
import { IFlashLoaner } from "./interfaces/IFlashLoaner.sol";

import { Arrays } from "../utils/Arrays.sol";

import { FixedPointMathLib } from "lib/solmate/src/utils/FixedPointMathLib.sol";

import { BaseWrapper, IERC7399, ERC20 } from "../BaseWrapper.sol";

/// @dev Balancer Flash Lender that uses Balancer Pools as source of liquidity.
/// Balancer allows pushing repayments, so we override `_repayTo`.
contract BalancerWrapper is BaseWrapper, IFlashLoanRecipient {
    using Arrays for uint256;
    using Arrays for address;
    using FixedPointMathLib for uint256;

    IFlashLoaner public immutable balancer;

    bytes32 private flashLoanDataHash;

    constructor(IFlashLoaner _balancer) {
        balancer = _balancer;
    }

    /// @inheritdoc IERC7399
    function maxFlashLoan(address asset) external view returns (uint256) {
        return _maxFlashLoan(asset);
    }

    /// @inheritdoc IERC7399
    function flashFee(address asset, uint256 amount) external view returns (uint256) {
        uint256 max = _maxFlashLoan(asset);
        require(max > 0, "Unsupported currency");
        return amount >= max ? type(uint256).max : _flashFee(amount);
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

        _bridgeToCallback(assets[0], amounts[0], fees[0], params);
    }

    function _flashLoan(address asset, uint256 amount, bytes memory data) internal override {
        flashLoanDataHash = keccak256(data);
        balancer.flashLoan(this, asset.toArray(), amount.toArray(), data);
    }

    function _repayTo() internal view override returns (address) {
        return address(balancer);
    }

    function _flashFee(uint256 amount) internal view returns (uint256) {
        return amount.mulWadUp(balancer.getProtocolFeesCollector().getFlashLoanFeePercentage());
    }

    function _maxFlashLoan(address asset) internal view returns (uint256) {
        return ERC20(asset).balanceOf(address(balancer));
    }
}
