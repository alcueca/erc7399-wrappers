// SPDX-License-Identifier: MIT
// Thanks to sunnyRK, yashnaman & ultrasecr.eth
pragma solidity ^0.8.19;

import { Registry } from "lib/registry/src/Registry.sol";

import { IUniswapV3FlashCallback } from "./interfaces/callback/IUniswapV3FlashCallback.sol";
import { IUniswapV3Pool } from "./interfaces/IUniswapV3Pool.sol";
import { PoolAddress } from "./interfaces/PoolAddress.sol";

import { BaseWrapper, IERC7399, ERC20 } from "../BaseWrapper.sol";

/// @dev Uniswap V3 Flash Lender that uses Uniswap V3 Pools as source of liquidity.
/// Uniswap V3 allows pushing repayments, so we override `_repayTo`.
contract UniswapV3Wrapper is BaseWrapper, IUniswapV3FlashCallback {
    using PoolAddress for address;
    using { canLoan, balance } for IUniswapV3Pool;

    error UnknownPool();
    error UnsupportedCurrency(address asset);

    // CONSTANTS
    address public immutable factory;

    // DEFAULT ASSETS
    address public immutable weth;
    address public immutable usdc;
    address public immutable usdt;

    /// @param reg Registry storing constructor parameters
    constructor(Registry reg) {
        // @param factory_ Uniswap v3 UniswapV3Factory address
        // @param weth_ Weth contract used in Uniswap v3 Pairs
        // @param usdc_ usdc contract used in Uniswap v3 Pairs
        // @param usdt_ usdt contract used in Uniswap v3 Pairs
        (factory, weth, usdc, usdt) = abi.decode(reg.get("UniswapV3Wrapper"), (address, address, address, address));
    }

    /**
     * @dev Get the Uniswap Pool that will be used as the source of a loan. The opposite asset will be Weth, except for
     * Weth that will be usdc.
     * @param asset The loan currency.
     * @param amount The amount of assets to borrow.
     * @return pool The Uniswap V3 Pool that will be used as the source of the flash loan.
     */
    function cheapestPool(address asset, uint256 amount) public view returns (IUniswapV3Pool pool) {
        // Try a stable pair first
        pool = _pool(asset, asset == usdc ? usdt : usdc, 0.0001e6);
        if (address(pool) != address(0) && pool.canLoan(asset, amount)) return pool;

        // Look for the cheapest fee otherwise
        uint16[3] memory fees = [0.0005e6, 0.003e6, 0.01e6];
        address assetOther = asset == weth ? usdc : weth;
        for (uint256 i = 0; i < 3; i++) {
            pool = _pool(asset, assetOther, fees[i]);
            if (address(pool) != address(0) && pool.canLoan(asset, amount)) return pool;
        }

        pool = IUniswapV3Pool(address(0));
    }

    /// @inheritdoc IERC7399
    function maxFlashLoan(address asset) external view returns (uint256) {
        return _maxFlashLoan(asset);
    }

    /// @inheritdoc IERC7399
    function flashFee(address asset, uint256 amount) external view returns (uint256) {
        uint256 max = _maxFlashLoan(asset);
        require(max > 0, "Unsupported currency");
        return amount >= max ? type(uint256).max : _flashFee(asset, amount);
    }

    function _flashLoan(address asset, uint256 amount, bytes memory data) internal override {
        IUniswapV3Pool pool = cheapestPool(asset, amount);
        if (address(pool) == address(0)) revert UnsupportedCurrency(asset);

        address asset0 = address(pool.token0());
        address asset1 = address(pool.token1());
        uint256 amount0 = asset == asset0 ? amount : 0;
        uint256 amount1 = asset == asset1 ? amount : 0;

        pool.flash(address(this), amount0, amount1, abi.encode(asset0, asset1, pool.fee(), amount, data));
    }

    /// @inheritdoc IUniswapV3FlashCallback
    function uniswapV3FlashCallback(
        uint256 fee0, // Fee on Asset0
        uint256 fee1, // Fee on Asset1
        bytes calldata params
    )
        external
        override
    {
        (address asset, address other, uint24 feeTier, uint256 amount, bytes memory data) =
            abi.decode(params, (address, address, uint24, uint256, bytes));
        if (msg.sender != address(_pool(asset, other, feeTier))) revert UnknownPool();

        uint256 fee = fee0 > 0 ? fee0 : fee1;
        _bridgeToCallback(asset, amount, fee, data);
    }

    function _flashLoan(address asset, uint256 amount, bytes memory data) internal override {
        IUniswapV3Pool pool = cheapestPool(asset, amount);
        require(address(pool) != address(0), "Unsupported currency");

        address asset0 = address(pool.token0());
        address asset1 = address(pool.token1());
        uint256 amount0 = asset == asset0 ? amount : 0;
        uint256 amount1 = asset == asset1 ? amount : 0;

        pool.flash(address(this), amount0, amount1, abi.encode(asset0, asset1, pool.fee(), amount, data));
    }

    function _repayTo() internal view override returns (address) {
        return msg.sender;
    }

    function _pool(address asset, address other, uint24 fee) internal view returns (IUniswapV3Pool pool) {
        PoolAddress.PoolKey memory poolKey = PoolAddress.getPoolKey(address(asset), address(other), fee);
        pool = IUniswapV3Pool(factory.computeAddress(poolKey));
    }

    function _maxFlashLoan(address asset) internal view returns (uint256 max) {
        // Try a stable pair first
        IUniswapV3Pool pool = _pool(asset, asset == usdc ? usdt : usdc, 0.0001e6);
        if (address(pool) != address(0)) {
            max = pool.balance(asset);
        }

        uint16[3] memory fees = [0.0005e6, 0.003e6, 0.01e6];
        address assetOther = asset == weth ? usdc : weth;
        for (uint256 i = 0; i < 3; i++) {
            pool = _pool(asset, assetOther, fees[i]);
            uint256 _balance = pool.balance(asset);
            if (address(pool) != address(0) && _balance > max) {
                max = _balance;
            }
        }
    }

    function _flashFee(address asset, uint256 amount) internal view returns (uint256) {
        IUniswapV3Pool pool = cheapestPool(asset, amount);
        require(address(pool) != address(0), "Unsupported currency");
        return amount * uint256(pool.fee()) / 1e6;
    }
}

function canLoan(IUniswapV3Pool pool, address asset, uint256 amount) view returns (bool) {
    return balance(pool, asset) >= amount;
}

function balance(IUniswapV3Pool pool, address asset) view returns (uint256) {
    return ERC20(asset).balanceOf(address(pool));
}
