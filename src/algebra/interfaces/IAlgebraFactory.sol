// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import { IAlgebraPool } from "./IAlgebraPool.sol";

interface IAlgebraFactory {
    function poolByPair(address, address) external view returns (IAlgebraPool);
}
