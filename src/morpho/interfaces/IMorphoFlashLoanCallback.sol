// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface IMorphoFlashLoanCallback {
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external;
}
