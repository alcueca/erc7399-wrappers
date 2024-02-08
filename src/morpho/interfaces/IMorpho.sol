// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface IMorpho {
    function flashLoan(address token, uint256 assets, bytes memory data) external;
}
