// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

interface IEVKFactoryPerspective {
    function isVerified(address vault) external view returns (bool);
    function verifiedArray() external view returns (address[] memory);
}
