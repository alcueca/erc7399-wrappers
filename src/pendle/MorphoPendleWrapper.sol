// SPDX-License-Identifier: MIT
// Thanks to ultrasecr.eth
pragma solidity ^0.8.19;

import { IMorphoFlashLoanCallback } from "../morpho/interfaces/IMorphoFlashLoanCallback.sol";
import { IMorpho } from "../morpho/interfaces/IMorpho.sol";

import { IPendleRouterV3 } from "./interfaces/IPendleRouterV3.sol";
import { IPPrincipalToken } from "./interfaces/IPPrincipalToken.sol";

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IERC7399, IERC20 } from "../BaseWrapper.sol";
import { BasePendleWrapper } from "./BasePendleWrapper.sol";

/// @dev Pendle Flash Lender that uses Morpho Pools as source of X liquidity,
/// then deposits X on Pendle to borrow whatever's necessary.
contract MorphoPendleWrapper is BasePendleWrapper, IMorphoFlashLoanCallback {
    using SafeERC20 for IERC20;

    error NotMorpho();

    uint256 private constant FEE = 0;

    IMorpho public immutable morpho;

    constructor(IMorpho _morpho, IPendleRouterV3 _pendleRouter) BasePendleWrapper(_pendleRouter) {
        morpho = _morpho;
    }

    /// @inheritdoc IERC7399
    function maxFlashLoan(address asset) public view returns (uint256) {
        IPPrincipalToken pt = IPPrincipalToken(asset);
        return pt.isExpired() ? 0 : pt.SY().yieldToken().balanceOf(address(morpho));
    }

    /// @inheritdoc IERC7399
    function flashFee(address asset, uint256 amount) external view returns (uint256) {
        uint256 max = maxFlashLoan(asset);
        return amount >= max ? type(uint256).max : FEE;
    }

    function _flashLoan(address asset, uint256 amount, bytes memory data) internal override {
        address underlying = address(IPPrincipalToken(asset).SY().yieldToken());
        bytes memory metadata = abi.encode(underlying, asset, data);
        morpho.flashLoan(underlying, amount, metadata);
    }

    function onMorphoFlashLoan(uint256 amount, bytes calldata params) external override {
        if (msg.sender != address(morpho)) revert NotMorpho();

        (IERC20 underlying, IERC20 asset, bytes memory data) = abi.decode(params, (IERC20, IERC20, bytes));

        _handleFlashLoan(underlying, asset, amount, FEE, data);

        _approveRepayment(address(underlying), amount, FEE);
    }
}
