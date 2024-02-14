// SPDX-License-Identifier: MIT
// Thanks to ultrasecr.eth
pragma solidity ^0.8.19;

import { Registry } from "lib/registry/src/Registry.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { AaveWrapper } from "./AaveWrapper.sol";

contract PermissionedAaveWrapper is AaveWrapper, AccessControl {
    bytes32 public constant BORROWER = keccak256("BORROWER");

    constructor(address owner, Registry reg, string memory name) AaveWrapper(reg, name) {
        _grantRole(DEFAULT_ADMIN_ROLE, owner);
    }

    function _flashLoan(address asset, uint256 amount, bytes memory data) internal override onlyRole(BORROWER) {
        super._flashLoan(asset, amount, data);
    }

    // This contract will be whitelisted in Aave so it pays 0 fees
    function _flashFee(uint256) internal pure override returns (uint256) {
        return 0;
    }
}
