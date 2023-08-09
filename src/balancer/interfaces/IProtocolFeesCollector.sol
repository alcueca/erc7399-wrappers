// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

interface IProtocolFeesCollector {
    function getFlashLoanFeePercentage() external view returns (uint256);
}
