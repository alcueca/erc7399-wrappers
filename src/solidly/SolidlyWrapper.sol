// SPDX-License-Identifier: MIT
// Thanks to sunnyRK, yashnaman & ultrasecr.eth
pragma solidity ^0.8.19;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { Registry } from "src/Registry.sol";

import { IPoolFactory } from "./interfaces/IPoolFactory.sol";
import { IPoolCallee } from "./interfaces/IPoolCallee.sol";
import { IPool } from "./interfaces/IPool.sol";

import { BaseWrapper, IERC7399, IERC20 } from "../BaseWrapper.sol";

/// @dev Solidly Flash Lender that uses Solidly Pools as source of liquidity.
/// Solidly allows pushing repayments, so we override `_repayTo`.
contract SolidlyWrapper is BaseWrapper, IPoolCallee {
    using { canLoan, balance } for IPool;

    uint256 private constant WAD = 1e18;

    error Unauthorized();
    error UnknownPool();
    error UnsupportedCurrency(address asset);

    // CONSTANTS
    IPoolFactory public immutable factory;

    // DEFAULT ASSETS
    address public immutable weth;
    address public immutable usdc;

    /// @param reg Registry storing constructor parameters
    constructor(string memory name, Registry reg) {
        // @param factory_ Solidly SolidlyFactory address
        // @param weth_ Weth contract used in Solidly Pairs
        // @param usdc_ usdc contract used in Solidly Pairs
        (factory, weth, usdc) = abi.decode(reg.getSafe(name), (IPoolFactory, address, address));
    }

    /**
     * @dev Get the Solidly Pool that will be used as the source of a loan. The opposite asset will be WETH, except for
     * WETH that will be usdc.
     * @param asset The loan currency.
     * @param amount The amount of assets to borrow.
     * @return pool The Solidly Pool that will be used as the source of the flash loan.
     */
    function cheapestPool(address asset, uint256 amount) public view returns (IPool pool, uint256 fee, bool stable) {
        address assetOther = asset == weth ? usdc : weth;
        IPool sPool = _pool(asset, assetOther, true);
        IPool vPool = _pool(asset, assetOther, false);

        uint256 sFee = address(sPool) != address(0) ? factory.getFee(sPool, true) : type(uint256).max;
        uint256 vFee = address(vPool) != address(0) ? factory.getFee(vPool, false) : type(uint256).max;

        if (sFee < vFee) {
            if (sPool.canLoan(asset, amount)) return (sPool, sFee, true);
            if (vPool.canLoan(asset, amount)) return (vPool, vFee, false);
        } else {
            if (vPool.canLoan(asset, amount)) return (vPool, vFee, false);
            if (sPool.canLoan(asset, amount)) return (sPool, sFee, true);
        }
    }

    /// @inheritdoc IERC7399
    function maxFlashLoan(address asset) external view returns (uint256) {
        return _maxFlashLoan(asset);
    }

    function _feeAmount(uint256 amount, uint256 fee) internal pure returns (uint256) {
        uint256 feeWAD = fee * 1e14;
        uint256 derivedFee = Math.mulDiv(WAD, WAD, WAD - feeWAD, Math.Rounding.Ceil) - WAD;
        return Math.mulDiv(amount, derivedFee, WAD, Math.Rounding.Ceil);
    }

    /// @inheritdoc IERC7399
    function flashFee(address asset, uint256 amount) external view returns (uint256) {
        (IPool pool, uint256 fee,) = cheapestPool(asset, amount);
        if (address(pool) == address(0)) revert UnsupportedCurrency(asset);

        return _feeAmount(amount, fee);
    }

    /// @inheritdoc IPoolCallee
    function hook(address sender, uint256 amount0, uint256 amount1, bytes calldata params) external override {
        (address asset0, address asset1, uint256 fee, bool stable, bytes memory data) =
            abi.decode(params, (address, address, uint256, bool, bytes));

        IPool pool = _pool(asset0, asset1, stable);
        if (msg.sender != address(pool)) revert UnknownPool();
        if (sender != address(this)) revert Unauthorized();

        (address asset, uint256 amount) = amount0 > 0 ? (asset0, amount0) : (asset1, amount1);

        _bridgeToCallback(asset, amount, _feeAmount(amount, fee), data);
    }

    function _flashLoan(address asset, uint256 amount, bytes memory data) internal override {
        (IPool pool, uint256 fee, bool stable) = cheapestPool(asset, amount);
        if (address(pool) == address(0)) revert UnsupportedCurrency(asset);

        (address asset0, address asset1) = pool.tokens();
        uint256 amount0 = asset == asset0 ? amount : 0;
        uint256 amount1 = asset == asset1 ? amount : 0;
        bytes memory params = abi.encode(asset0, asset1, fee, stable, data);

        pool.swap(amount0, amount1, address(this), params);
    }

    function _repayTo() internal view override returns (address) {
        return msg.sender;
    }

    function _pool(address tokenA, address tokenB, bool stable) internal view returns (IPool pool) {
        (tokenA, tokenB) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        pool = factory.getPool(tokenA, tokenB, stable);
    }

    function _maxFlashLoan(address asset) internal view returns (uint256 max) {
        address assetOther = asset == weth ? usdc : weth;
        IPool stable = _pool(asset, assetOther, true);
        IPool volatile = _pool(asset, assetOther, false);

        uint256 stableBalance = balance(stable, asset);
        uint256 volatileBalance = balance(volatile, asset);

        return stableBalance > volatileBalance ? stableBalance : volatileBalance;
    }
}

function canLoan(IPool pool, address asset, uint256 amount) view returns (bool) {
    return balance(pool, asset) >= amount;
}

function balance(IPool pool, address asset) view returns (uint256) {
    return IERC20(asset).balanceOf(address(pool));
}
