// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <=0.9.0;

import { Script } from "forge-std/Script.sol";

abstract contract BaseScript is Script {
    modifier broadcast(string memory fork) {
        vm.createSelectFork(fork);
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }

    /// @dev Returns true if `account` is a contract.
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.
        return account.code.length > 0;
    }

    /// @dev Returns the address of a contract's bytecode.
    function getAddress(
        bytes memory bytecode,
        bytes32 _salt
    ) public view returns (address) {
        bytes32 hash = keccak256(
            abi.encodePacked(bytes1(0xff), address(this), _salt, keccak256(bytecode))
        );

        // NOTE: cast last 20 bytes of hash to address
        return address(uint160(uint(hash)));
    }
}
