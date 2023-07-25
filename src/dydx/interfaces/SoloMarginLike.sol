// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../libraries/DYDXDataTypes.sol";

interface SoloMarginLike {
    function operate(DYDXDataTypes.AccountInfo[] memory accounts, DYDXDataTypes.ActionArgs[] memory actions) external;
    function getMarketTokenAddress(uint256 marketId) external view returns (address);
}
