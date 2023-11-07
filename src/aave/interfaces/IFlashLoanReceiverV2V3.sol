// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.19;

/**
 * @title IFlashLoanReceiver interface
 * @notice Interface for the Aave fee IFlashLoanReceiver (V2/V3 compatible).
 * @author Aave
 * @dev implement this interface to develop a flashloan-compatible flashLoanReceiver contract
 *
 */
interface IFlashLoanReceiverV2V3 {
    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    )
        external
        returns (bool);

    function ADDRESSES_PROVIDER() external view returns (address);

    function LENDING_POOL() external view returns (address);

    function POOL() external view returns (address);
}
