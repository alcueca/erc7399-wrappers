// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

interface IEVault {
    function flashLoan(uint256 amount, bytes memory data) external;
    function asset() external view returns (address);
}
