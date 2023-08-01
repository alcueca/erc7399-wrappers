// SPDX-License-Identifier: GPL-3.0-or-later
// Thanks to ultrasecr.eth
pragma solidity ^0.8.0;

import { IFlashLoanRecipient } from "./interfaces/IFlashLoanRecipient.sol";
import { IFlashLoaner } from "./interfaces/IFlashLoaner.sol";

import { Arrays } from "../utils/Arrays.sol";

import { FixedPointMathLib } from "lib/solmate/src/utils/FixedPointMathLib.sol";
import { IERC20 } from "lib/erc3156pp/src/interfaces/IERC20.sol";

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

    function flashFee(IERC20 asset, uint256 amount) external view returns (uint256 fee) {
        if (amount >= asset.balanceOf(address(balancer))) fee = type(uint256).max;
        else fee = amount.mulWadUp(balancer.getProtocolFeesCollector().getFlashLoanFeePercentage());
    }

    function _flashLoan(IERC20 asset, uint256 amount, bytes memory data) internal override {
        flashLoanDataHash = keccak256(data);
        balancer.flashLoan(this, address(asset).toArray(), amount.toArray(), data);
    }

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

        _handleFlashLoan(IERC20(assets[0]), amounts[0], fees[0], params);
    }

    function _repayTo() internal view override returns (address) {
        return address(balancer);
    }
}
