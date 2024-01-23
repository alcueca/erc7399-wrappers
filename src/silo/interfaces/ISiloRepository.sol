// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { ISilo } from "./ISilo.sol";

interface ISiloRepository {
    struct AssetConfig {
        uint64 maxLoanToValue;
        uint64 liquidationThreshold;
        address interestRateModel;
    }

    struct Fees {
        uint64 entryFee;
        uint64 protocolShareFee;
        uint64 protocolLiquidationFee;
    }

    error AssetAlreadyAdded();
    error AssetIsNotABridge();
    error AssetIsZero();
    error BridgeAssetIsZero();
    error ConfigDidNotChange();
    error EmptyBridgeAssets();
    error FeesDidNotChange();
    error GlobalLimitDidNotChange();
    error GlobalPauseDidNotChange();
    error InterestRateModelDidNotChange();
    error InvalidEntryFee();
    error InvalidInterestRateModel();
    error InvalidLTV();
    error InvalidLiquidationThreshold();
    error InvalidNotificationReceiver();
    error InvalidPriceProvidersRepository();
    error InvalidProtocolLiquidationFee();
    error InvalidProtocolShareFee();
    error InvalidSiloFactory();
    error InvalidSiloRouter();
    error InvalidSiloVersion();
    error InvalidTokensFactory();
    error LastBridgeAsset();
    error LiquidationThresholdDidNotChange();
    error ManagerDidNotChange();
    error ManagerIsZero();
    error MaxLiquidityDidNotChange();
    error MaximumLTVDidNotChange();
    error NoPriceProviderForAsset();
    error NotificationReceiverDidNotChange();
    error OnlyManager();
    error OnlyOwnerOrManager();
    error PriceProviderRepositoryDidNotChange();
    error RouterDidNotChange();
    error SiloAlreadyExistsForAsset();
    error SiloAlreadyExistsForBridgeAssets();
    error SiloDoesNotExist();
    error SiloIsZero();
    error SiloMaxLiquidityDidNotChange();
    error SiloNotAllowedForBridgeAsset();
    error SiloPauseDidNotChange();
    error SiloVersionDoesNotExist();
    error TokenIsNotAContract();
    error VersionForAssetDidNotChange();

    event AssetConfigUpdate(address indexed silo, address indexed asset, AssetConfig assetConfig);
    event BridgeAssetAdded(address indexed newBridgeAsset);
    event BridgeAssetRemoved(address indexed bridgeAssetRemoved);
    event BridgePool(address indexed pool);
    event DefaultSiloMaxDepositsLimitUpdate(uint256 newMaxDeposits);
    event FeeUpdate(uint64 newEntryFee, uint64 newProtocolShareFee, uint64 newProtocolLiquidationFee);
    event GlobalPause(bool globalPause);
    event InterestRateModel(address indexed newModel);
    event LimitedMaxLiquidityToggled(bool newLimitedMaxLiquidityState);
    event ManagerChanged(address manager);
    event NewDefaultLiquidationThreshold(uint64 defaultLiquidationThreshold);
    event NewDefaultMaximumLTV(uint64 defaultMaximumLTV);
    event NewSilo(address indexed silo, address indexed asset, uint128 siloVersion);
    event NotificationReceiverUpdate(address indexed newIncentiveContract);
    event OwnershipPending(address indexed newPendingOwner);
    event OwnershipTransferred(address indexed newOwner);
    event PriceProvidersRepositoryUpdate(address indexed newProvider);
    event RegisterSiloVersion(address indexed factory, uint128 siloLatestVersion, uint128 siloDefaultVersion);
    event RouterUpdate(address indexed newRouter);
    event SiloDefaultVersion(uint128 newDefaultVersion);
    event SiloMaxDepositsLimitsUpdate(address indexed silo, address indexed asset, uint256 newMaxDeposits);
    event SiloPause(address silo, address asset, bool pauseValue);
    event TokensFactoryUpdate(address indexed newTokensFactory);
    event UnregisterSiloVersion(address indexed factory, uint128 siloVersion);
    event VersionForAsset(address indexed asset, uint128 version);

    function acceptOwnership() external;
    function addBridgeAsset(address _newBridgeAsset) external;
    function assetConfigs(
        address,
        address
    )
        external
        view
        returns (uint64 maxLoanToValue, uint64 liquidationThreshold, address interestRateModel);
    function bridgePool() external view returns (address);
    function changeManager(address _manager) external;
    function defaultAssetConfig()
        external
        view
        returns (uint64 maxLoanToValue, uint64 liquidationThreshold, address interestRateModel);
    function ensureCanCreateSiloFor(address _asset, bool _assetIsABridge) external view;
    function entryFee() external view returns (uint256);
    function fees() external view returns (uint64 entryFee, uint64 protocolShareFee, uint64 protocolLiquidationFee);
    function getBridgeAssets() external view returns (address[] memory);
    function getInterestRateModel(address _silo, address _asset) external view returns (address model);
    function getLiquidationThreshold(address _silo, address _asset) external view returns (uint256);
    function getMaxSiloDepositsValue(address _silo, address _asset) external view returns (uint256);
    function getMaximumLTV(address _silo, address _asset) external view returns (uint256);
    function getNotificationReceiver(address) external view returns (address);
    function getRemovedBridgeAssets() external view returns (address[] memory);
    function getSilo(ERC20) external view returns (ISilo);
    function getVersionForAsset(address) external view returns (uint128);
    function isPaused() external view returns (bool globalPause);
    function isSilo(address _silo) external view returns (bool);
    function isSiloPaused(address _silo, address _asset) external view returns (bool);
    function manager() external view returns (address);
    function maxLiquidity() external view returns (bool globalLimit, uint256 defaultMaxLiquidity);
    function newSilo(address _siloAsset, bytes memory _siloData) external returns (address);
    function owner() external view returns (address);
    function pendingOwner() external view returns (address);
    function priceProvidersRepository() external view returns (address);
    function protocolLiquidationFee() external view returns (uint256);
    function protocolShareFee() external view returns (uint256);
    function registerSiloVersion(address _factory, bool _isDefault) external;
    function removeBridgeAsset(address _bridgeAssetToRemove) external;
    function removePendingOwnership() external;
    function renounceOwnership() external;
    function replaceSilo(address _siloAsset, uint128 _siloVersion, bytes memory _siloData) external returns (address);
    function router() external view returns (address);
    function setAssetConfig(address _silo, address _asset, AssetConfig memory _assetConfig) external;
    function setDefaultInterestRateModel(address _defaultInterestRateModel) external;
    function setDefaultLiquidationThreshold(uint64 _defaultLiquidationThreshold) external;
    function setDefaultMaximumLTV(uint64 _defaultMaxLTV) external;
    function setDefaultSiloMaxDepositsLimit(uint256 _maxDeposits) external;
    function setDefaultSiloVersion(uint128 _defaultVersion) external;
    function setFees(Fees memory _fees) external;
    function setGlobalPause(bool _globalPause) external;
    function setLimitedMaxLiquidity(bool _globalLimit) external;
    function setNotificationReceiver(address _silo, address _newNotificationReceiver) external;
    function setPriceProvidersRepository(address _repository) external;
    function setRouter(address _router) external;
    function setSiloMaxDepositsLimit(address _silo, address _asset, uint256 _maxDeposits) external;
    function setSiloPause(address _silo, address _asset, bool _pauseValue) external;
    function setTokensFactory(address _tokensFactory) external;
    function setVersionForAsset(address _siloAsset, uint128 _version) external;
    function siloFactory(uint256) external view returns (address);
    function siloRepositoryPing() external pure returns (bytes4);
    function siloReverse(address) external view returns (address);
    function siloVersion() external view returns (uint128 byDefault, uint128 latest);
    function tokensFactory() external view returns (address);
    function transferOwnership(address newOwner) external;
    function transferPendingOwnership(address newPendingOwner) external;
    function unregisterSiloVersion(uint128 _siloVersion) external;
}
