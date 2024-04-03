// SPDX-License-Identifier: MIT
// Thanks to ultrasecr.eth
pragma solidity ^0.8.19;

import { IAlgebraPool } from "./interfaces/IAlgebraPool.sol";
import { IAlgebraFactory } from "./interfaces/IAlgebraFactory.sol";
import { IAlgebraFlashCallback } from "./interfaces/IAlgebraFlashCallback.sol";

import { Registry } from "src/Registry.sol";

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { Arrays } from "../utils/Arrays.sol";

import { BaseWrapper, IERC7399, IERC20 } from "../BaseWrapper.sol";

/// @dev Algebra Flash Lender that uses Algebra Pools as source of liquidity.
/// Algebra allows pushing repayments, so we override `_repayTo`.
contract AlgebraWrapper is BaseWrapper, IAlgebraFlashCallback {
    using Arrays for uint256;
    using Arrays for address;

    error HashMismatch();
    error UnsupportedCurrency();
    error Unauthorized();

    // CONSTANTS
    IAlgebraFactory public immutable factory;

    // DEFAULT ASSETS
    address public immutable weth;
    address public immutable usdc;

    /// @param reg Registry storing constructor parameters
    constructor(string memory name, Registry reg) {
        // @param factory_ Solidly SolidlyFactory address
        // @param weth_ Weth contract used in Solidly Pairs
        // @param usdc_ usdc contract used in Solidly Pairs
        (factory, weth, usdc) = abi.decode(reg.getSafe(name), (IAlgebraFactory, address, address));
    }

    /// @inheritdoc IERC7399
    function maxFlashLoan(address asset) public view returns (uint256) {
        (IAlgebraPool pool,) = _pool(asset);
        return IERC20(asset).balanceOf(address(pool));
    }

    /// @inheritdoc IERC7399
    function flashFee(address asset, uint256 amount) external view returns (uint256) {
        uint256 max = maxFlashLoan(asset);
        require(max > 0, "Unsupported currency");
        return amount >= max ? type(uint256).max : _flashFee(amount);
    }

    /// @inheritdoc IAlgebraFlashCallback
    function algebraFlashCallback(uint256 fee0, uint256 fee1, bytes calldata params) external override {
        (address asset, address other, uint256 amount, bytes memory data) =
            abi.decode(params, (address, address, uint256, bytes));
        if (msg.sender != address(factory.poolByPair(asset, other))) revert Unauthorized();

        _bridgeToCallback(asset, amount, fee0 > 0 ? fee0 : fee1, data);
    }

    function _flashLoan(address asset, uint256 amount, bytes memory data) internal override {
        (IAlgebraPool pool, address other) = _pool(asset);
        bytes memory params = abi.encode(asset, other, amount, data);

        uint256 amount0 = pool.token0() == asset ? amount : 0;
        uint256 amount1 = amount0 > 0 ? 0 : amount;

        pool.flash(msg.sender, amount0, amount1, params);
    }

    function _repayTo() internal view override returns (address) {
        return msg.sender;
    }

    // solhint-disable-next-line no-empty-blocks
    function _transferAssets(address asset, uint256 amount, address loanReceiver) internal override {
        // Nothing to do
    }

    function _flashFee(uint256 amount) internal pure returns (uint256) {
        return Math.mulDiv(amount, 1e2, 1e6, Math.Rounding.Ceil);
    }

    function _pool(address asset) internal view returns (IAlgebraPool pool, address other) {
        other = asset == weth ? usdc : weth;
        pool = factory.poolByPair(asset, other);
        if (address(pool) == address(0)) {
            other = usdc;
            pool = factory.poolByPair(asset, other);
        }

        if (address(pool) == address(0)) revert UnsupportedCurrency();
    }
}
