// SPDX-License-Identifier: MIT
// Thanks to ultrasecr.eth
pragma solidity ^0.8.19;

import { IPendleRouterV3 } from "./interfaces/IPendleRouterV3.sol";
import { IPPrincipalToken } from "./interfaces/IPPrincipalToken.sol";
import { IPYieldToken } from "./interfaces/IPYieldToken.sol";

import { Arrays } from "../utils/Arrays.sol";

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { BaseWrapper, IERC20 } from "../BaseWrapper.sol";

/// @dev Pendle Flash Lender that uses other sources of X liquidity,
/// then deposits X on Pendle to mint whatever's necessary.
abstract contract BasePendleWrapper is BaseWrapper {
    using Arrays for uint256;
    using Arrays for address;

    using SafeERC20 for IERC20;
    using SafeERC20 for IPYieldToken;

    IPendleRouterV3 public immutable pendleRouter;

    constructor(IPendleRouterV3 _pendleRouter) {
        pendleRouter = _pendleRouter;
    }

    function _handleFlashLoan(
        IERC20 underlying,
        IERC20 asset,
        uint256 amount,
        uint256 fee,
        bytes memory data
    )
        internal
    {
        IPYieldToken yt = IPPrincipalToken(address(asset)).YT();

        underlying.forceApprove(address(pendleRouter), amount);
        (uint256 netPyOut,) =
            pendleRouter.mintPyFromToken(address(this), yt, 0, _createTokenInputStruct(underlying, amount));

        _bridgeToCallback(address(asset), amount, fee, data);

        asset.forceApprove(address(pendleRouter), netPyOut);
        yt.forceApprove(address(pendleRouter), netPyOut);
        pendleRouter.redeemPyToToken(address(this), yt, netPyOut, _createTokenOutputStruct(underlying, 0));
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
}
