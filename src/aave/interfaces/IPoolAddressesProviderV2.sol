// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

interface IPoolAddressesProviderV2 {
    function getLendingPool() external view returns (address);
}
