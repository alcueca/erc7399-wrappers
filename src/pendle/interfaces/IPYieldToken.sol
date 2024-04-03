// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IPYieldToken is IERC20Metadata {
    function SY() external view returns (address);

    function PT() external view returns (address);
}
