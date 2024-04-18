// SPDX-License-Identifier: MIT
// Thanks to ultrasecr.eth
pragma solidity ^0.8.19;

import { IGnosisSafe } from "./interfaces/IGnosisSafe.sol";

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import { Enum } from "./lib/Enum.sol";
import { BaseWrapper, IERC7399, IERC20 } from "../BaseWrapper.sol";

/// @dev Safe Gnosis Flash Lender that uses individual Gnosis Safe contracts as source of liquidity.
contract GnosisSafeWrapper is BaseWrapper, AccessControl, Initializable {
    error UnsupportedAsset(address asset);
    error FailedTransfer(address asset, uint256 amount);
    error InsufficientRepayment(address asset, uint256 amount);

    event LendingDataSet(address asset, uint248 fee, bool enabled);
    event SafeSet(IGnosisSafe safe);

    struct LendingData {
        uint248 fee; // 1 = 0.01%
        bool enabled;
    }

    address public constant ALL_ASSETS = address(0);

    IGnosisSafe public safe;

    mapping(address asset => LendingData data) public lending;
    
    function initialize(address _safe) public initializer {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        safe = IGnosisSafe(_safe);
        emit SafeSet(safe);
    }

    /// @inheritdoc IERC7399
    function maxFlashLoan(address asset) public view returns (uint256) {
        if (lending[asset].enabled == true || lending[ALL_ASSETS].enabled == true) {
            return IERC20(asset).balanceOf(address(safe));
        } else {
            return 0;
        }
    }

    /// @inheritdoc IERC7399
    function flashFee(address asset, uint256 amount) public view returns (uint256) {
        uint256 max = maxFlashLoan(asset);
        if (max == 0) revert UnsupportedAsset(asset); // TODO: Should we revert on tokens that are enabled but have zero
            // liquidity?
        if (amount >= max) {
            return type(uint256).max;
        } else {
            uint256 fee = lending[ALL_ASSETS].enabled == true ? lending[ALL_ASSETS].fee : lending[asset].fee;
            return amount * fee / 10_000;
        }
    }

    function _flashLoan(address asset, uint256 amount, bytes memory params) internal override {
        Data memory decodedParams = abi.decode(params, (Data));

        uint256 fee = flashFee(asset, amount); // Checks for unsupported assets
        uint256 balanceAfter = IERC20(asset).balanceOf(address(safe)) + fee;

        // Take assets from safe
        bytes memory transferCall =
            abi.encodeWithSignature("transfer(address,uint256)", decodedParams.loanReceiver, amount);
        if (!safe.execTransactionFromModule(asset, 0, transferCall, Enum.Operation.Call)) {
            revert FailedTransfer(asset, amount);
        }

        // Call callback
        _bridgeToCallback(asset, amount, fee, params);

        // Make sure assets are back in safe (TODO: think about reentrancy)
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
    function lend(address asset, uint248 fee, bool enabled) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (asset == ALL_ASSETS) revert UnsupportedAsset(asset); // address(0) is reserved for the all assets override
        lending[asset] = LendingData({ fee: fee, enabled: enabled });
        emit LendingDataSet(asset, fee, enabled);
    }

    /// @dev Set a lending data override for all assets.
    /// @param fee Fee for the flash loan (FP 1e-4)
    /// @param enabled Whether the lending data override is enabled for flash loans.
    function lendAll(uint248 fee, bool enabled) public onlyRole(DEFAULT_ADMIN_ROLE) {
        lending[ALL_ASSETS] = LendingData({ fee: fee, enabled: enabled });
        emit LendingDataSet(ALL_ASSETS, fee, enabled);
    }
}
