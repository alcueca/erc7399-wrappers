// SPDX-License-Identifier: MIT
// Thanks to ultrasecr.eth
pragma solidity ^0.8.19;

import { IGnosisSafe } from "./interfaces/IGnosisSafe.sol";

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

import { Enum } from "./lib/Enum.sol";
import { BaseWrapper, IERC7399, IERC20 } from "../BaseWrapper.sol";

/// @dev Safe Gnosis Flash Lender that uses individual Gnosis Safe contracts as source of liquidity.
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

    mapping(address asset => LendingData data) public lending;

    /// @param _safe The Gnosis Safe to use as the source of liquidity, and as the owner of this contract.
    constructor(IGnosisSafe _safe) {
        _grantRole(DEFAULT_ADMIN_ROLE, address(_safe));
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
        return amount >= max ? type(uint256).max : amount * lending[asset].fee / 10_000;
    }

    function _flashLoan(address asset, uint256 amount, bytes memory params) internal override {
        Data memory decodedParams = abi.decode(params, (Data));

        if (lending[asset].enabled == false) revert UnsupportedAsset(asset);
        uint256 fee = flashFee(asset, amount);
        uint256 balanceAfter = IERC20(asset).balanceOf(address(safe)) + fee;

        // Take assets from safe
        bytes memory transferCall =
            abi.encodeWithSignature("transfer(address,uint256)", decodedParams.loanReceiver, amount);
        if (!safe.execTransactionFromModule(asset, 0, transferCall, Enum.Operation.Call)) {
            revert FailedTransfer(asset, amount);
        }

        // Call callback
        _bridgeToCallback(asset, amount, fee, params);

        // Make sure assets are back in safe (think about reentrancy)
        if (IERC20(asset).balanceOf(address(safe)) < balanceAfter) revert InsufficientRepayment(asset, amount + fee);
    }

    /// @dev Transfer the assets to the loan receiver.
    /// Overriden because the provider can send the funds directly
    // solhint-disable-next-line no-empty-blocks
    function _transferAssets(address, uint256, address) internal override { }

    /// @dev Where should the end client send the funds to repay the loan
    /// Overriden because the provider can receive the funds directly
    function _repayTo() internal view override returns (address) {
        return address(safe);
    }

    /// @dev Set lending data for an asset.
    /// @param asset Address of the asset.
    /// @param fee Fee for the flash loan (FP 1e-4)
    /// @param enabled Whether the asset is enabled for flash loans.
    function setLendingData(address asset, uint248 fee, bool enabled) public onlyRole(DEFAULT_ADMIN_ROLE) {
        lending[asset] = LendingData({ fee: fee, enabled: enabled });
        emit LendingDataSet(asset, fee, enabled);
    }
}
