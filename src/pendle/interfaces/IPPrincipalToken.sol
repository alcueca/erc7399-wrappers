// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "./IStandardizedYield.sol";
import "./IPYieldToken.sol";

interface IPPrincipalToken is IERC20Metadata {
    function SY() external view returns (IStandardizedYield);

    function YT() external view returns (IPYieldToken);

    function isExpired() external view returns (bool);
}
