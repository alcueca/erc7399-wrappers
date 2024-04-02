// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "./IPYieldToken.sol";

interface IPendleRouterV3 {
    enum SwapType {
        NONE,
        KYBERSWAP,
        ONE_INCH,
        // ETH_WETH not used in Aggregator
        ETH_WETH
    }

    struct SwapData {
        SwapType swapType;
        address extRouter;
        bytes extCalldata;
        bool needScale;
    }

    struct TokenInput {
        // TOKEN DATA
        address tokenIn;
        uint256 netTokenIn;
        address tokenMintSy;
        // AGGREGATOR DATA
        address pendleSwap;
        SwapData swapData;
    }

    struct TokenOutput {
        // TOKEN DATA
        address tokenOut;
        uint256 minTokenOut;
        address tokenRedeemSy;
        // AGGREGATOR DATA
        address pendleSwap;
        SwapData swapData;
    }

    function mintPyFromToken(
        address receiver,
        IPYieldToken YT,
        uint256 minPyOut,
        TokenInput calldata input
    )
        external
        payable
        returns (uint256 netPyOut, uint256 netSyInterm);

    function redeemPyToToken(
        address receiver,
        IPYieldToken YT,
        uint256 netPyIn,
        TokenOutput calldata output
    )
        external
        returns (uint256 netTokenOut, uint256 netSyInterm);
}
