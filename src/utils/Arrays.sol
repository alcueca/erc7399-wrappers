// SPDX-License-Identifier: MIT
// Thanks to ultrasecr.eth
pragma solidity ^0.8.19;

library Arrays {
    function toArray(uint256 n) internal pure returns (uint256[] memory arr) {
        arr = new uint256[](1);
        arr[0] = n;
    }

    function toArray(address a) internal pure returns (address[] memory arr) {
        arr = new address[](1);
        arr[0] = a;
    }
}
