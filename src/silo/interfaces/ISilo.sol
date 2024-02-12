// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import { IERC20Metadata as IERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface ISilo {
    type AssetStatus is uint8;

    struct AssetInterestData {
        uint256 harvestedProtocolFees;
        uint256 protocolFees;
        uint64 interestRateTimestamp;
        AssetStatus status;
    }

    struct AssetStorage {
        address collateralToken;
        address collateralOnlyToken;
        address debtToken;
        uint256 totalDeposits;
        uint256 collateralOnlyDeposits;
        uint256 totalBorrowAmount;
    }

    struct UtilizationData {
        uint256 totalDeposits;
        uint256 totalBorrowAmount;
        uint64 interestRateTimestamp;
    }

    error AssetDoesNotExist();
    error BorrowNotPossible();
    error DepositNotPossible();
    error DepositsExceedLimit();
    error DifferentArrayLength();
    error InvalidRepository();
    error InvalidSiloVersion();
    error LiquidationReentrancyCall();
    error MaximumLTVReached();
    error NotEnoughDeposits();
    error NotEnoughLiquidity();
    error NotSolvent();
    error OnlyRouter();
    error Paused();
    error TokenIsNotAContract();
    error UnexpectedEmptyReturn();
    error UnsupportedLTVType();
    error UserIsZero();
    error ZeroAssets();
    error ZeroShares();

    event AssetStatusUpdate(address indexed asset, AssetStatus indexed status);
    event Borrow(address indexed asset, address indexed user, uint256 amount);
    event Deposit(address indexed asset, address indexed depositor, uint256 amount, bool collateralOnly);
    event Liquidate(address indexed asset, address indexed user, uint256 shareAmountRepaid, uint256 seizedCollateral);
    event Repay(address indexed asset, address indexed user, uint256 amount);
    event Withdraw(
        address indexed asset, address indexed depositor, address indexed receiver, uint256 amount, bool collateralOnly
    );

    function VERSION() external view returns (uint128);
    function accrueInterest(IERC20 _asset) external returns (uint256 interest);
    function assetStorage(IERC20 _asset) external view returns (AssetStorage memory);
    function borrow(IERC20 _asset, uint256 _amount) external returns (uint256 debtAmount, uint256 debtShare);
    function borrowFor(
        IERC20 _asset,
        address _borrower,
        address _receiver,
        uint256 _amount
    )
        external
        returns (uint256 debtAmount, uint256 debtShare);
    function borrowPossible(IERC20 _asset, address _borrower) external view returns (bool);
    function deposit(
        IERC20 _asset,
        uint256 _amount,
        bool _collateralOnly
    )
        external
        returns (uint256 collateralAmount, uint256 collateralShare);
    function depositFor(
        IERC20 _asset,
        address _depositor,
        uint256 _amount,
        bool _collateralOnly
    )
        external
        returns (uint256 collateralAmount, uint256 collateralShare);
    function depositPossible(IERC20 _asset, address _depositor) external view returns (bool);
    function flashLiquidate(
        address[] memory _users,
        bytes memory _flashReceiverData
    )
        external
        returns (
            address[] memory assets,
            uint256[][] memory receivedCollaterals,
            uint256[][] memory shareAmountsToRepay
        );
    function getAssets() external view returns (address[] memory assets);
    function getAssetsWithState()
        external
        view
        returns (address[] memory assets, AssetStorage[] memory assetsStorage);
    function harvestProtocolFees() external returns (uint256[] memory harvestedAmounts);
    function initAssetsTokens() external;
    function interestData(IERC20 _asset) external view returns (AssetInterestData memory);
    function isSolvent(address _user) external view returns (bool);
    function liquidity(IERC20 _asset) external view returns (uint256);
    function repay(IERC20 _asset, uint256 _amount) external returns (uint256 repaidAmount, uint256 repaidShare);
    function repayFor(
        IERC20 _asset,
        address _borrower,
        uint256 _amount
    )
        external
        returns (uint256 repaidAmount, uint256 repaidShare);
    function siloAsset() external view returns (address);
    function siloRepository() external view returns (address);
    function syncBridgeAssets() external;
    function utilizationData(IERC20 _asset) external view returns (UtilizationData memory data);
    function withdraw(
        IERC20 _asset,
        uint256 _amount,
        bool _collateralOnly
    )
        external
        returns (uint256 withdrawnAmount, uint256 withdrawnShare);
    function withdrawFor(
        IERC20 _asset,
        address _depositor,
        address _receiver,
        uint256 _amount,
        bool _collateralOnly
    )
        external
        returns (uint256 withdrawnAmount, uint256 withdrawnShare);
}
