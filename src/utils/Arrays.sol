// SPDX-License-Identifier: GPL-3.0-or-later
// Thanks to ultrasecr.eth
pragma solidity ^0.8.0;


library Arrays {
    function toArray(uint256 n) external pure returns (uint256[] memory arr) {
        arr = new uint[](1);
        arr[0] = n;
    }

    function toArray(address a) external pure returns (address[] memory arr) {
        arr = new address[](1);
        arr[0] = a;
    }
}