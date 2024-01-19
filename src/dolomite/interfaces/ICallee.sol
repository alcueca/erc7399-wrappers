// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "./IDolomiteMargin.sol";

interface ICallee {
    function callFunction(address sender, IDolomiteMargin.Info memory accountInfo, bytes memory data) external;
}
