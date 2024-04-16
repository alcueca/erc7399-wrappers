// SPDX-License-Identifier: MIT
// Thanks to ultrasecr.eth
pragma solidity ^0.8.19;

import { IGnosisSafe } from "./interfaces/IGnosisSafe.sol";

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

import { Enum } from "./lib/Enum.sol";
import { BaseWrapper, IERC7399, IERC20 } from "../BaseWrapper.sol";

/// @dev MorphoBlue Flash Lender that uses MorphoBlue as source of liquidity.
contract GnosisSafeWrapper is BaseWrapper, AccessControl {
    error UnsupportedAsset(address asset);
    error FailedTransfer(address asset, uint256 amount);
    error InsufficientRepayment(address asset, uint256 amount);

    event LendingDataSet(address asset, uint248 fee, bool enabled);

    struct LendingData {
        uint248 fee; // 1 = 0.01%
        bool enabled;
    }

    IGnosisSafe public immutable safe;

    mapping (address asset => LendingData data) public lending;

    constructor(IGnosisSafe _safe) {
        safe = _safe;
    }

    /// @inheritdoc IERC7399
    function maxFlashLoan(address asset) public view returns (uint256) {
        if (lending[asset].enabled == false) return 0;
        return IERC20(asset).balanceOf(address(safe));
    }

    /// @inheritdoc IERC7399
    function flashFee(address asset, uint256 amount) public view returns (uint256) {
        uint256 max = maxFlashLoan(asset);
        if (max == 0) revert UnsupportedAsset(asset);
        return amount >= max ? type(uint256).max : amount * lending[asset].fee / 10000;
    }

    function _flashLoan(address asset, uint256 amount, bytes memory params) internal override {

        Data memory decodedParams = abi.decode(params, (Data));
        
        if (lending[asset].enabled == false) revert UnsupportedAsset(asset);
        uint256 fee = flashFee(asset, amount);
        uint256 balanceAfter = IERC20(asset).balanceOf(address(safe)) + fee;

        // Take assets from safe
        bytes memory transferCall = abi.encodeWithSignature("transfer(address,uint256)", decodedParams.loanReceiver, amount);
        if (!safe.execTransactionFromModule(asset, 0, transferCall, Enum.Operation.Call)) revert FailedTransfer(asset, amount);

        // Call callback
        _bridgeToCallback(asset, amount, 0, params);

        // Make sure assets are back in safe (think about reentrancy)
        if (IERC20(asset).balanceOf(address(safe)) < balanceAfter) revert InsufficientRepayment(asset, amount + fee);
    }

    function setLendingData(address asset, uint248 fee, bool enabled) public onlyRole(DEFAULT_ADMIN_ROLE) {
        lending[asset] = LendingData({ fee: fee, enabled: enabled });
        emit LendingDataSet(asset, fee, enabled);
    }
}
