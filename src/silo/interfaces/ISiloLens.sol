// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { ISiloRepository } from "./ISiloRepository.sol";
import { ISilo } from "./ISilo.sol";

interface ISiloLens {
    error DifferentArrayLength();
    error InvalidRepository();
    error UnsupportedLTVType();
    error ZeroAssets();

    function balanceOfUnderlying(
        uint256 _assetTotalDeposits,
        address _shareToken,
        address _user
    )
        external
        view
        returns (uint256);
    function borrowAPY(address _silo, address _asset) external view returns (uint256);
    function borrowShare(address _silo, address _asset, address _user) external view returns (uint256);
    function calcFee(uint256 _amount) external view returns (uint256);
    function calculateBorrowValue(address _silo, address _user, address _asset) external view returns (uint256);
    function calculateCollateralValue(address _silo, address _user, address _asset) external view returns (uint256);
    function collateralBalanceOfUnderlying(
        address _silo,
        address _asset,
        address _user
    )
        external
        view
        returns (uint256);
    function collateralOnlyDeposits(address _silo, address _asset) external view returns (uint256);
    function debtBalanceOfUnderlying(address _silo, address _asset, address _user) external view returns (uint256);
    function depositAPY(address _silo, address _asset) external view returns (uint256);
    function getBorrowAmount(
        address _silo,
        address _asset,
        address _user,
        uint256 _timestamp
    )
        external
        view
        returns (uint256);
    function getModel(address _silo, address _asset) external view returns (address);
    function getUserLTV(address _silo, address _user) external view returns (uint256 userLTV);
    function getUserLiquidationThreshold(
        address _silo,
        address _user
    )
        external
        view
        returns (uint256 liquidationThreshold);
    function getUserMaximumLTV(address _silo, address _user) external view returns (uint256 maximumLTV);
    function getUtilization(address _silo, address _asset) external view returns (uint256);
    function hasPosition(address _silo, address _user) external view returns (bool);
    function inDebt(address _silo, address _user) external view returns (bool);
    function lensPing() external pure returns (bytes4);
    function liquidity(ISilo _silo, ERC20 _asset) external view returns (uint256);
    function protocolFees(address _silo, address _asset) external view returns (uint256);
    function siloRepository() external view returns (ISiloRepository);
    function totalBorrowAmount(address _silo, address _asset) external view returns (uint256);
    function totalBorrowAmountWithInterest(
        address _silo,
        address _asset
    )
        external
        view
        returns (uint256 _totalBorrowAmount);
    function totalBorrowShare(address _silo, address _asset) external view returns (uint256);
    function totalDeposits(address _silo, address _asset) external view returns (uint256);
    function totalDepositsWithInterest(address _silo, address _asset) external view returns (uint256 _totalDeposits);
}
