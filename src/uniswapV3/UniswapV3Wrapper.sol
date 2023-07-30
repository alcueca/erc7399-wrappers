// SPDX-License-Identifier: GPL-3.0-or-later
// Thanks to sunnyRK and yashnaman
pragma solidity ^0.8.0;

import { IUniswapV3FlashCallback } from "./interfaces/callback/IUniswapV3FlashCallback.sol";
import { IUniswapV3Pool } from "./interfaces/IUniswapV3Pool.sol";
import { IUniswapV3Factory } from "./interfaces/IUniswapV3Factory.sol";

import { IERC20 } from "lib/erc3156pp/src/interfaces/IERC20.sol";

import { BaseWrapper } from "../BaseWrapper.sol";

contract UniswapV3Wrapper is BaseWrapper, IUniswapV3FlashCallback {
    // CONSTANTS
    IUniswapV3Factory public immutable factory;

    // ACCESS CONTROL
    IUniswapV3Pool internal _activePool;

    // DEFAULT ASSETS
    IERC20 weth;
    IERC20 dai;

    /// @param factory_ Uniswap v3 UniswapV3Factory address
    /// @param weth_ Weth contract used in Uniswap v3 Pairs
    /// @param dai_ dai contract used in Uniswap v3 Pairs
    constructor(IUniswapV3Factory factory_, IERC20 weth_, IERC20 dai_) {
        factory = factory_;
        weth = weth_;
        dai = dai_;
    }

    /**
     * @dev Get the Uniswap Pool that will be used as the source of a loan. The opposite asset will be Weth, except for
     * Weth that will be Dai.
     * @param asset The loan currency.
     * @return The Uniswap V3 Pool that will be used as the source of the flash loan.
     */
    function getPool(IERC20 asset) public view returns (IUniswapV3Pool) {
        IERC20 assetOther = asset == weth ? dai : weth;
        return IUniswapV3Pool(factory.getPool(address(asset), address(assetOther), 3000));
    }

    /**
     * @dev From ERC-3156. The fee to be charged for a given loan.
     * @param asset The loan currency.
     * @param amount The amount of assets lent.
     * @return The amount of `asset` to be charged for the loan, on top of the returned principal.
     */
    function flashFee(IERC20 asset, uint256 amount) public view override returns (uint256) {
        IUniswapV3Pool pool = getPool(asset);
        if (asset.balanceOf(address(pool)) < amount) return type(uint256).max;
        return amount * uint256(pool.fee()) / 1e6;
    }

    function _flashLoan(IERC20 asset, uint256 amount, bytes memory data) internal override {
        IUniswapV3Pool pool = getPool(asset);
        require(address(pool) != address(0), "Unsupported currency");

        IERC20 asset0 = IERC20(pool.token0());
        IERC20 asset1 = IERC20(pool.token1());
        uint256 amount0 = asset == asset0 ? amount : 0;
        uint256 amount1 = asset == asset1 ? amount : 0;

        _activePool = pool;
        pool.flash(address(this), amount0, amount1, data);
        delete _activePool;
    }

    // Flashswap Callback
    function uniswapV3FlashCallback(
        uint256 fee0, // Fee on Asset0
        uint256 fee1, // Fee on Asset1
        bytes calldata params
    )
        external
        override
    {
        require(msg.sender == address(_activePool), "Only active pool");

        uint256 fee = fee0 > 0 ? fee0 : fee1;
        IERC20 asset = IERC20(fee0 > 0 ? IUniswapV3Pool(msg.sender).token0() : IUniswapV3Pool(msg.sender).token1());
        uint256 amount = asset.balanceOf(address(this));

        _handleFlashLoan(asset, amount, fee, params);
    }

    function _repayTo() internal view override returns (address) {
        return msg.sender;
    }
}
