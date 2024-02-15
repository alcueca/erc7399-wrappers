// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.19;

import { IPoolDataProvider } from "./IPoolDataProvider.sol";

interface IPoolAddressesProviderV3 {
    function getPool() external view returns (address);

    function getPoolDataProvider() external view returns (IPoolDataProvider);

    function getACLManager() external view returns (address);
}
