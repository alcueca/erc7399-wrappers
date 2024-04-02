// SPDX-License-Identifier: MIT
// Thanks to ultrasecr.eth
pragma solidity ^0.8.19;

import { IFlashLoanRecipient } from "../balancer/interfaces/IFlashLoanRecipient.sol";
import { IFlashLoaner } from "../balancer/interfaces/IFlashLoaner.sol";

import { IPendleRouterV3 } from "./interfaces/IPendleRouterV3.sol";
import { IPPrincipalToken } from "./interfaces/IPPrincipalToken.sol";
import { IPYieldToken } from "./interfaces/IPYieldToken.sol";

import { Arrays } from "../utils/Arrays.sol";
import { WAD } from "../utils/constants.sol";

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { BaseWrapper, IERC7399, IERC20 } from "../BaseWrapper.sol";

/// @dev Pendle Flash Lender that uses Balancer Pools as source of X liquidity,
/// then deposits X on Pendle to borrow whatever's necessary.
contract PendleWrapper is BaseWrapper, IFlashLoanRecipient {
    using Arrays for uint256;
    using Arrays for address;

    using SafeERC20 for IERC20;
    using SafeERC20 for IPYieldToken;

    error NotBalancer();
    error HashMismatch();

    IFlashLoaner public immutable balancer;
    IPendleRouterV3 public immutable pendleRouter;

    bytes32 private flashLoanDataHash;

    constructor(IFlashLoaner _balancer, IPendleRouterV3 _pendleRouter) {
        balancer = _balancer;
        pendleRouter = _pendleRouter;
    }

    /// @inheritdoc IERC7399
    function maxFlashLoan(address asset) public view returns (uint256) {
        return IPPrincipalToken(asset).SY().yieldToken().balanceOf(address(balancer));
    }

    /// @inheritdoc IERC7399
    function flashFee(address asset, uint256 amount) external view returns (uint256) {
        uint256 max = maxFlashLoan(asset);
        uint256 fee = Math.mulDiv(
            amount, balancer.getProtocolFeesCollector().getFlashLoanFeePercentage(), WAD, Math.Rounding.Ceil
        );
        // If Balancer ever charges a fee, we can't repay it with the flash loan, so this wrapper becomes useless
        return amount >= max || fee > 0 ? type(uint256).max : 0;
    }

    function _flashLoan(address asset, uint256 amount, bytes memory data) internal override {
        bytes memory metadata = abi.encode(asset, data);
        flashLoanDataHash = keccak256(metadata);
        IERC20 underlying = IPPrincipalToken(asset).SY().yieldToken();
        balancer.flashLoan(this, address(underlying).toArray(), amount.toArray(), metadata);
    }

    /// @inheritdoc IFlashLoanRecipient
    function receiveFlashLoan(
        address[] memory assets,
        uint256[] memory amounts,
        uint256[] memory,
        bytes memory params
    )
        external
        override
    {
        if (msg.sender != address(balancer)) revert NotBalancer();
        if (keccak256(params) != flashLoanDataHash) revert HashMismatch();
        delete flashLoanDataHash;

        (IERC20 asset, bytes memory data) = abi.decode(params, (IERC20, bytes));

        IERC20 underlying = IERC20(assets[0]);
        uint256 amount = amounts[0];
        IPYieldToken yt = IPPrincipalToken(address(asset)).YT();

        underlying.forceApprove(address(pendleRouter), amount);
        (uint256 netPyOut,) =
            pendleRouter.mintPyFromToken(address(this), yt, 0, _createTokenInputStruct(underlying, amount));

        _bridgeToCallback(address(asset), amount, 0, data);

        asset.forceApprove(address(pendleRouter), netPyOut);
        yt.forceApprove(address(pendleRouter), netPyOut);
        pendleRouter.redeemPyToToken(address(this), yt, netPyOut, _createTokenOutputStruct(underlying, 0));

        underlying.safeTransfer(address(balancer), amount);
    }

    function _createTokenInputStruct(
        IERC20 tokenIn,
        uint256 netTokenIn
    )
        internal
        pure
        returns (IPendleRouterV3.TokenInput memory)
    {
        IPendleRouterV3.SwapData memory emptySwap;
        return IPendleRouterV3.TokenInput({
            tokenIn: address(tokenIn),
            netTokenIn: netTokenIn,
            tokenMintSy: address(tokenIn),
            pendleSwap: address(0),
            swapData: emptySwap
        });
    }

    function _createTokenOutputStruct(
        IERC20 tokenOut,
        uint256 minTokenOut
    )
        internal
        pure
        returns (IPendleRouterV3.TokenOutput memory)
    {
        IPendleRouterV3.SwapData memory emptySwap;
        return IPendleRouterV3.TokenOutput({
            tokenOut: address(tokenOut),
            minTokenOut: minTokenOut,
            tokenRedeemSy: address(tokenOut),
            pendleSwap: address(0),
            swapData: emptySwap
        });
    }

    function _approveRepayment(address, uint256, uint256) internal override {
        // Nothing to do here
    }
}
