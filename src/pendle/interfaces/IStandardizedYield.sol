// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IStandardizedYield {
    function yieldToken() external view returns (IERC20Metadata);
}
