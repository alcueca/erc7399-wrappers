// SPDX-License-Identifier: MIT
// Thanks to ultrasecr.eth
pragma solidity ^0.8.19;

import { IAlgebraPool } from "../algebra/interfaces/IAlgebraPool.sol";
import { IAlgebraFactory } from "../algebra/interfaces/IAlgebraFactory.sol";
import { IAlgebraFlashCallback } from "../algebra/interfaces/IAlgebraFlashCallback.sol";

import { IPendleRouterV3 } from "./interfaces/IPendleRouterV3.sol";
import { IPPrincipalToken } from "./interfaces/IPPrincipalToken.sol";

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

import { Arrays } from "../utils/Arrays.sol";

import { IERC7399, IERC20 } from "../BaseWrapper.sol";
import { BasePendleWrapper } from "./BasePendleWrapper.sol";

/// @dev Pendle Flash Lender that uses Algebra Pools as source of X liquidity,
/// then deposits X on Pendle to borrow whatever's necessary.
contract AlgebraPendleWrapper is BasePendleWrapper, IAlgebraFlashCallback, AccessControl {
    using Arrays for uint256;
    using Arrays for address;

    using SafeERC20 for IERC20;

    error HashMismatch();
    error UnsupportedCurrency();
    error Unauthorized();

    // CONSTANTS
    IAlgebraFactory public immutable factory;

    // DEFAULT ASSETS
    address public immutable weth;
    address public immutable usdc;

    constructor(
        address owner,
        IAlgebraFactory _factory,
        address _weth,
        address _usdc,
        IPendleRouterV3 _pendleRouter
    )
        BasePendleWrapper(_pendleRouter)
    {
        _grantRole(DEFAULT_ADMIN_ROLE, owner);
        factory = _factory;
        weth = _weth;
        usdc = _usdc;
    }

    /// @inheritdoc IERC7399
    function maxFlashLoan(address asset) public view returns (uint256) {
        if (IPPrincipalToken(asset).isExpired()) return 0;

        IERC20 underlying = IPPrincipalToken(asset).SY().yieldToken();
        (IAlgebraPool pool,) = _pool(address(underlying));
        uint256 poolBalance = underlying.balanceOf(address(pool));
        uint256 myBalance = underlying.balanceOf(address(this));

        uint256 maxAmountForFee = Math.mulDiv(myBalance, 1e6, 1e2, Math.Rounding.Floor);

        return Math.min(poolBalance, maxAmountForFee);
    }

    /// @inheritdoc IERC7399
    function flashFee(address asset, uint256 amount) external view returns (uint256) {
        uint256 max = maxFlashLoan(asset);
        require(max > 0, "Unsupported currency");
        return amount >= max ? type(uint256).max : _flashFee(amount);
    }

    /// @inheritdoc IAlgebraFlashCallback
    function algebraFlashCallback(uint256 fee0, uint256 fee1, bytes calldata params) external override {
        (IERC20 underlying, IERC20 asset, address other, uint256 amount, bytes memory data) =
            abi.decode(params, (IERC20, IERC20, address, uint256, bytes));
        if (msg.sender != address(factory.poolByPair(address(underlying), other))) revert Unauthorized();

        uint256 fee = fee0 > 0 ? fee0 : fee1;

        _handleFlashLoan(underlying, asset, amount, fee, data);

        underlying.safeTransfer(msg.sender, amount + fee);
    }

    function _flashLoan(address asset, uint256 amount, bytes memory data) internal override {
        IERC20 underlying = IPPrincipalToken(asset).SY().yieldToken();
        (IAlgebraPool pool, address other) = _pool(address(underlying));
        bytes memory params = abi.encode(underlying, asset, other, amount, data);

        uint256 amount0 = pool.token0() == address(underlying) ? amount : 0;
        uint256 amount1 = amount0 > 0 ? 0 : amount;

        pool.flash(address(this), amount0, amount1, params);
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

    function retrieve(IERC20 asset, address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        asset.safeTransfer(to, amount);
    }
}
