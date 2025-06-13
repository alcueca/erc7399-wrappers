// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { BaseWrapper, IERC20 } from "../BaseWrapper.sol";
import { IEFlashLoanCallback } from "./interfaces/IEFlashLoanCallback.sol";
import { IEVKFactoryPerspective } from "./interfaces/IEVKFactoryPerspective.sol";
import { IEVault } from "./interfaces/IEVault.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @dev Euler Flash Lender that uses Euler as source of liquidity.
contract EulerWrapper is BaseWrapper, IEFlashLoanCallback {
    using SafeERC20 for IERC20;

    error UnsupportedAsset(address asset);
    error UnverifiedVault();

    /**
     * @dev No vault for the provided asset
     */
    error UnavailableVault();

    error InsufficientRepayment(address asset, uint256 amount);

    /**
     * @dev A vault doesn't have liquidity
     */
    error NoLiquidity();

    /**
     * @dev A vault exists for a given token
     */
    event VaultExists();

    /**
     * @dev If a vault was removed
     */
    event VaultRemoved();

    event VaultsAdded(uint256 count);

    mapping(IERC20 token => IEVault[] vaults) public tokenVaults;

    IEVKFactoryPerspective internal evkFactory;

    constructor(IEVKFactoryPerspective evkFactoryPerspective) {
        evkFactory = evkFactoryPerspective;
        address[] memory vaultList = evkFactory.verifiedArray();
        for (uint256 i = 0; i < vaultList.length; ++i) {
            IEVault vault = IEVault(vaultList[i]);
            address asset = vault.asset();
            IERC20 token = IERC20(asset);
            addVault(token, vault);
        }
        emit VaultsAdded(vaultList.length);
    }

    function addVault(IERC20 token, IEVault vault) public {
        if (!evkFactory.isVerified(address(vault))) revert UnverifiedVault();

        // Check for duplicates
        IEVault[] storage vaults = tokenVaults[token];
        for (uint256 i = 0; i < vaults.length; ++i) {
            if (vaults[i] == vault) {
                emit VaultExists();
                return;
            }
        }
        tokenVaults[token].push(vault);
    }

    function removeVault(IERC20 token, IEVault vault) public {
        IEVault[] storage vaults = tokenVaults[token];
        uint256 len = vaults.length;

        for (uint256 i = 0; i < len; i++) {
            if (vaults[i] == vault) {
                vaults[i] = vaults[len - 1];
                vaults.pop();
                emit VaultRemoved();
                break;
            }
        }
    }

    function getVaultCount(IERC20 token) external view returns (uint256) {
        return tokenVaults[token].length;
    }

    function maxFlashLoan(address asset) public view returns (uint256) {
        IEVault[] memory vaults = tokenVaults[IERC20(asset)];
        uint256 balance = 0;

        for (uint256 i = 0; i < vaults.length; ++i) {
            uint256 vaultBalance = IERC20(asset).balanceOf(address(vaults[i]));
            if (vaultBalance > balance) {
                balance = vaultBalance;
            }
        }

        return balance;
    }

    function flashFee(address asset, uint256 amount) external view returns (uint256) {
        uint256 max = maxFlashLoan(asset);
        if (max == 0) revert UnsupportedAsset(asset);
        return amount >= max ? type(uint256).max : 0;
    }

    function onFlashLoan(bytes calldata params) external override {
        (address asset, uint256 amount, bytes memory data) = abi.decode(params, (address, uint256, bytes));
        _bridgeToCallback(asset, amount, 0, data);
    }

    function _flashLoan(address asset, uint256 amount, bytes memory data) internal override {
        IEVault[] memory vaults = tokenVaults[IERC20(asset)];

        // Ensure the vaults array is not empty
        if (vaults.length == 0) {
            revert UnavailableVault();
        }

        // find a vault with enough liquidity
        IEVault vault;
        for (uint256 i = 0; i < vaults.length; ++i) {
            uint256 vaultBalance = IERC20(asset).balanceOf(address(vaults[i]));
            if (vaultBalance > amount) {
                vault = vaults[i];
                break;
            }
        }

        if (address(vault) == address(0)) {
            revert NoLiquidity();
        }

        vault.flashLoan(amount, abi.encode(asset, amount, data));
    }

    function _repayTo() internal view override returns (address) {
        return msg.sender;
    }
}
