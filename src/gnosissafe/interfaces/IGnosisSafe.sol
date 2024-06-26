// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.8.0;

import { Enum } from "../lib/Enum.sol";

interface IGnosisSafe {
    /// @dev Allows a Module to execute a Safe transaction without any further confirmations.
    /// @param to Destination address of module transaction.
    /// @param value Ether value of module transaction.
    /// @param data Data payload of module transaction.
    /// @param operation Operation type of module transaction.
    function execTransactionFromModule(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation
    )
        external
        returns (bool success);

    /// @notice Enables the module `module` for the Safe.
    /// @dev This can only be done via a Safe transaction.
    /// @param module Module to be whitelisted.
    function enableModule(address module) external;
}
