// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface IAlgebraPool {
    function token0() external view returns (address);
    function token1() external view returns (address);

    function flash(address recipient, uint256 amount0, uint256 amount1, bytes memory data) external;
}
