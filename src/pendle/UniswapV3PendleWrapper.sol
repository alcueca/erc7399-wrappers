// SPDX-License-Identifier: MIT
// Thanks to ultrasecr.eth
pragma solidity ^0.8.19;

import { IUniswapV3FlashCallback } from "../uniswapV3/interfaces/callback/IUniswapV3FlashCallback.sol";
import { IUniswapV3Pool } from "../uniswapV3/interfaces/IUniswapV3Pool.sol";
import { PoolAddress } from "../uniswapV3/interfaces/PoolAddress.sol";

import { IPendleRouterV3 } from "./interfaces/IPendleRouterV3.sol";
import { IPPrincipalToken } from "./interfaces/IPPrincipalToken.sol";

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

import { IERC7399, IERC20 } from "../BaseWrapper.sol";
import { BasePendleWrapper } from "./BasePendleWrapper.sol";

/// @dev Pendle Flash Lender that uses UniswapV3 Pools as source of X liquidity,
/// then deposits X on Pendle to borrow whatever's necessary.
contract UniswapV3PendleWrapper is BasePendleWrapper, IUniswapV3FlashCallback, AccessControl {
    using PoolAddress for address;
    using { canLoan, balance } for IUniswapV3Pool;

    using SafeERC20 for IERC20;

    error UnsupportedCurrency(address asset);
    error Unauthorized();
    error UnknownPool();

    address public immutable factory;
    address public immutable weth;

    constructor(
        address owner,
        address _factory,
        address _weth,
        IPendleRouterV3 _pendleRouter
    )
        BasePendleWrapper(_pendleRouter)
    {
        _grantRole(DEFAULT_ADMIN_ROLE, owner);
        factory = _factory;
        weth = _weth;
    }

    /**
     * @dev Get the Uniswap Pool that will be used as the source of a loan. The opposite asset will be Weth
     * @param asset The loan currency.
     * @param amount The amount of assets to borrow.
     * @return pool The Uniswap V3 Pool that will be used as the source of the flash loan.
     */
    function cheapestPool(address asset, uint256 amount) public view returns (IUniswapV3Pool pool, uint24 fee) {
        uint16[4] memory fees = [0.0001e6, 0.0005e6, 0.003e6, 0.01e6];
        for (uint256 i = 0; i < 4; i++) {
            pool = _pool(asset, fees[i]);
            if (address(pool) != address(0) && pool.canLoan(asset, amount)) return (pool, fees[i]);
        }

        pool = IUniswapV3Pool(address(0));
    }

    /// @inheritdoc IERC7399
    function maxFlashLoan(address asset) public view returns (uint256) {
        IERC20 underlying = IPPrincipalToken(asset).SY().yieldToken();
        (, uint256 poolBalance, uint24 poolFee) = _maxFlashLoan(address(underlying));
        if (poolBalance == 0) return 0;

        uint256 myBalance = underlying.balanceOf(address(this));
        uint256 maxAmountForFee = Math.mulDiv(myBalance, 1e6, poolFee, Math.Rounding.Floor);

        return Math.min(poolBalance, maxAmountForFee);
    }

    /// @inheritdoc IERC7399
    function flashFee(address asset, uint256 amount) external view returns (uint256) {
        uint256 max = maxFlashLoan(asset);
        if (max == 0) revert UnsupportedCurrency(asset);
        IERC20 underlying = IPPrincipalToken(asset).SY().yieldToken();
        (, uint256 poolFee) = cheapestPool(address(underlying), amount);
        return amount >= max ? type(uint256).max : Math.mulDiv(amount, poolFee, 1e6, Math.Rounding.Ceil);
    }

    function retrieve(IERC20 asset, address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        asset.safeTransfer(to, amount);
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
        (IERC20 underlying, IERC20 asset, uint24 feeTier, uint256 amount, bytes memory data) =
            abi.decode(params, (IERC20, IERC20, uint24, uint256, bytes));
        if (msg.sender != address(_pool(address(underlying), feeTier))) revert UnknownPool();

        uint256 fee = fee0 > 0 ? fee0 : fee1;

        _handleFlashLoan(underlying, asset, amount, fee, data);

        underlying.safeTransfer(msg.sender, amount + fee);
    }

    function _flashLoan(address asset, uint256 amount, bytes memory data) internal override {
        address underlying = address(IPPrincipalToken(asset).SY().yieldToken());
        (IUniswapV3Pool pool, uint24 fee) = cheapestPool(underlying, amount);
        if (address(pool) == address(0)) revert UnsupportedCurrency(asset);

        uint256 amount0 = pool.token0() == underlying ? amount : 0;
        uint256 amount1 = amount0 > 0 ? 0 : amount;

        pool.flash(address(this), amount0, amount1, abi.encode(underlying, asset, fee, amount, data));
    }

    function _maxFlashLoan(address asset)
        internal
        view
        returns (IUniswapV3Pool pool, uint256 poolBalance, uint24 poolFee)
    {
        uint16[4] memory fees = [0.0001e6, 0.0005e6, 0.003e6, 0.01e6];
        for (uint256 i = 0; i < 4; i++) {
            IUniswapV3Pool __pool = _pool(asset, fees[i]);
            uint256 _balance = __pool.balance(asset);
            if (address(__pool) != address(0) && _balance > poolBalance) {
                pool = __pool;
                poolBalance = _balance;
                poolFee = fees[i];
            }
        }
    }

    function _pool(address asset, uint24 fee) internal view returns (IUniswapV3Pool pool) {
        PoolAddress.PoolKey memory poolKey = PoolAddress.getPoolKey(asset, weth, fee);
        pool = IUniswapV3Pool(factory.computeAddress(poolKey));
    }
}

function canLoan(IUniswapV3Pool pool, address asset, uint256 amount) view returns (bool) {
    return balance(pool, asset) >= amount;
}

function balance(IUniswapV3Pool pool, address asset) view returns (uint256) {
    if (address(pool) == address(0)) return 0;
    return IERC20(asset).balanceOf(address(pool));
}
