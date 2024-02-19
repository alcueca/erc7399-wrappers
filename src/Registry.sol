// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

contract Registry is AccessControl {
    bytes32 public constant USER = keccak256("USER");

    event Registered(string key, bytes value);

    error NotFound();

    mapping(string key => bytes value) public get;

    constructor(address owner, address[] memory users) {
        _grantRole(DEFAULT_ADMIN_ROLE, owner);

        _grantRole(USER, owner);
        for (uint256 i = 0; i < users.length; i++) {
            _grantRole(USER, users[i]);
        }
    }

    function set(string memory key, bytes memory value) external onlyRole(USER) {
        get[key] = value;
        emit Registered(key, value);
    }

    function getSafe(string calldata key) external view returns (bytes memory result) {
        result = get[key];
        if (result.length == 0) {
            revert NotFound();
        }
    }
}
