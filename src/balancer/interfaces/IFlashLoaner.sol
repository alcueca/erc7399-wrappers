// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import { IFlashLoanRecipient } from "./IFlashLoanRecipient.sol";
import { IProtocolFeesCollector } from "./IProtocolFeesCollector.sol";

interface IFlashLoaner {
    function flashLoan(
        IFlashLoanRecipient recipient,
        address[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
    )
        external;

    function getProtocolFeesCollector() external view returns (IProtocolFeesCollector);
}
