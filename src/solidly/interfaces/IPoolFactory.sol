// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import { IPool } from "./IPool.sol";

interface IPoolFactory {
    error FeeInvalid();
    error FeeTooHigh();
    error InvalidPool();
    error NotFeeManager();
    error NotPauser();
    error NotVoter();
    error PoolAlreadyExists();
    error SameAddress();
    error ZeroAddress();
    error ZeroFee();

    function MAX_FEE() external view returns (uint256);
    function ZERO_FEE_INDICATOR() external view returns (uint256);
    function allPools(uint256) external view returns (address);
    function allPoolsLength() external view returns (uint256);
    function createPool(address tokenA, address tokenB, bool stable) external returns (address pool);
    function createPool(address tokenA, address tokenB, uint24 fee) external returns (address pool);
    function customFee(address) external view returns (uint256);
    function feeManager() external view returns (address);
    function getFee(IPool pool, bool _stable) external view returns (uint256);
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (IPool);
    function getPool(address tokenA, address tokenB, bool stable) external view returns (IPool);
    function implementation() external view returns (address);
    function isPaused() external view returns (bool);
    function isPool(IPool pool) external view returns (bool);
    function stableFee() external view returns (uint256);
    function volatileFee() external view returns (uint256);
    function voter() external view returns (address);
}
