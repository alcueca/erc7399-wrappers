// SPDX-License-Identifier: GPL-3.0-or-later
// Thanks to sunnyRK and yashnaman
pragma solidity ^0.8.0;

import { IUniswapV3FlashCallback } from "./interfaces/callback/IUniswapV3FlashCallback.sol";
import { IUniswapV3Pool } from "./interfaces/IUniswapV3Pool.sol";
import { PoolAddress } from "./interfaces/PoolAddress.sol";

import { IERC20 } from "lib/erc3156pp/src/interfaces/IERC20.sol";

import { BaseWrapper } from "../BaseWrapper.sol";

contract UniswapV3Wrapper is BaseWrapper, IUniswapV3FlashCallback {
    using PoolAddress for address;

    // CONSTANTS
    address public immutable factory;

    // ACCESS CONTROL
    IUniswapV3Pool internal _activePool;

    // DEFAULT ASSETS
    IERC20 weth;
    IERC20 usdc;
    IERC20 usdt;

    /// @param factory_ Uniswap v3 UniswapV3Factory address
    /// @param weth_ Weth contract used in Uniswap v3 Pairs
    /// @param usdc_ usdc contract used in Uniswap v3 Pairs
    /// @param usdt_ usdt contract used in Uniswap v3 Pairs
    constructor(address factory_, IERC20 weth_, IERC20 usdc_, IERC20 usdt_) {
        factory = factory_;
        weth = weth_;
        usdc = usdc_;
        usdt = usdt_;
    }

    /**
     * @dev Get the Uniswap Pool that will be used as the source of a loan. The opposite asset will be Weth, except for
     * Weth that will be usdc.
     * @param asset The loan currency.
     * @param amount The amount of assets to borrow.
     * @return pool The Uniswap V3 Pool that will be used as the source of the flash loan.
     */
    function getPool(IERC20 asset, uint256 amount) public view returns (IUniswapV3Pool pool) {
        // Try a stable pair first
        pool = _checkPool(asset, asset == usdc ? usdt : usdc, 0.0001e6, amount);
        if (address(pool) != address(0)) return pool;

        // Look for the cheapest fee otherwise
        uint16[3] memory fees = [0.0005e6, 0.003e6, 0.01e6];
        IERC20 assetOther = asset == weth ? usdc : weth;
        for (uint256 i = 0; i < 3; i++) {
            pool = _checkPool(asset, assetOther, fees[i], amount);
            if (address(pool) != address(0)) return pool;
        }

        pool = IUniswapV3Pool(address(0));
    }

    function _checkPool(
        IERC20 asset,
        IERC20 other,
        uint24 fee,
        uint256 amount
    )
        internal
        view
        returns (IUniswapV3Pool poolAddress)
    {
        PoolAddress.PoolKey memory poolKey = PoolAddress.getPoolKey(address(asset), address(other), fee);
        poolAddress = IUniswapV3Pool(factory.computeAddress(poolKey));
        poolAddress = asset.balanceOf(address(poolAddress)) >= amount ? poolAddress : IUniswapV3Pool(address(0));
    }

    /**
     * @dev From ERC-3156. The fee to be charged for a given loan.
     * @param asset The loan currency.
     * @param amount The amount of assets lent.
     * @return The amount of `asset` to be charged for the loan, on top of the returned principal.
     */
    function flashFee(IERC20 asset, uint256 amount) public view override returns (uint256) {
        IUniswapV3Pool pool = getPool(asset, amount);
        if (address(pool) == address(0)) return type(uint256).max;
        return amount * uint256(pool.fee()) / 1e6;
    }

    function _flashLoan(IERC20 asset, uint256 amount, bytes memory data) internal override {
        IUniswapV3Pool pool = getPool(asset, amount);
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
        require(msg.sender == address(_activePool), "UniswapV3Wrapper: Only active pool");

        uint256 fee = fee0 > 0 ? fee0 : fee1;
        IERC20 asset = IERC20(fee0 > 0 ? IUniswapV3Pool(msg.sender).token0() : IUniswapV3Pool(msg.sender).token1());
        uint256 amount = asset.balanceOf(address(this));

        _handleFlashLoan(asset, amount, fee, params);
    }

    function _repayTo() internal view override returns (address) {
        return msg.sender;
    }
}
