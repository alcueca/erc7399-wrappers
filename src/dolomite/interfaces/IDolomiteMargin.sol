// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface IDolomiteMargin {
    enum ActionType {
        Deposit,   // supply tokens
        Withdraw,  // borrow tokens
        Transfer,  // transfer balance between accounts
        Buy,       // buy an amount of some token (externally)
        Sell,      // sell an amount of some token (externally)
        Trade,     // trade tokens against another account
        Liquidate, // liquidate an undercollateralized or expiring account
        Vaporize,  // use excess tokens to zero-out a completely negative account
        Call       // send arbitrary data to an address
    }

    enum AssetDenomination {
        Wei, // the amount is denominated in wei
        Par  // the amount is denominated in par
    }

    enum AssetReference {
        Delta, // the amount is given as a delta from the current value
        Target // the amount is given as an exact number to end up at
    }
    
    type Status is uint8;

    struct ActionArgs {
        ActionType actionType;
        uint256 accountId;
        AssetAmount amount;
        uint256 primaryMarketId;
        uint256 secondaryMarketId;
        address otherAddress;
        uint256 otherAccountId;
        bytes data;
    }

    struct AssetAmount {
        bool sign;
        AssetDenomination denomination;
        AssetReference ref;
        uint256 value;
    }

    struct D256 {
        uint256 value;
    }

    struct Index {
        uint96 borrow;
        uint96 supply;
        uint32 lastUpdate;
    }

    struct Info {
        address owner;
        uint256 number;
    }

    struct Market {
        address token;
        bool isClosing;
        bool isRecyclable;
        TotalPar totalPar;
        Index index;
        address priceOracle;
        address interestSetter;
        D256 marginPremium;
        D256 spreadPremium;
        Wei maxWei;
    }

    struct OperatorArg {
        address operator;
        bool trusted;
    }

    struct Par {
        bool sign;
        uint128 value;
    }

    struct Price {
        uint256 value;
    }

    struct Rate {
        uint256 value;
    }

    struct RiskLimits {
        uint64 marginRatioMax;
        uint64 liquidationSpreadMax;
        uint64 earningsRateMax;
        uint64 marginPremiumMax;
        uint64 spreadPremiumMax;
        uint128 minBorrowedValueMax;
    }

    struct RiskParams {
        D256 marginRatio;
        D256 liquidationSpread;
        D256 earningsRate;
        Value minBorrowedValue;
        uint256 accountMaxNumberOfMarketsWithBalances;
    }

    struct TotalPar {
        uint128 borrow;
        uint128 supply;
    }

    struct Value {
        uint256 value;
    }

    struct Wei {
        bool sign;
        uint256 value;
    }

    event LogOperatorSet(address indexed owner, address operator, bool trusted);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function getAccountBalances(Info memory account)
        external
        view
        returns (uint256[] memory, address[] memory, Par[] memory, Wei[] memory);
    function getAccountMarketWithBalanceAtIndex(Info memory account, uint256 index) external view returns (uint256);
    function getAccountMarketsWithBalances(Info memory account) external view returns (uint256[] memory);
    function getAccountMaxNumberOfMarketsWithBalances() external view returns (uint256);
    function getAccountNumberOfMarketsWithBalances(Info memory account) external view returns (uint256);
    function getAccountNumberOfMarketsWithDebt(Info memory account) external view returns (uint256);
    function getAccountPar(Info memory account, uint256 marketId) external view returns (Par memory);
    function getAccountParNoMarketCheck(Info memory account, uint256 marketId) external view returns (Par memory);
    function getAccountStatus(Info memory account) external view returns (Status);
    function getAccountValues(Info memory account) external view returns (Value memory, Value memory);
    function getAccountWei(Info memory account, uint256 marketId) external view returns (Wei memory);
    function getAdjustedAccountValues(Info memory account) external view returns (Value memory, Value memory);
    function getEarningsRate() external view returns (D256 memory);
    function getIsAutoTraderSpecial(address autoTrader) external view returns (bool);
    function getIsGlobalOperator(address operator) external view returns (bool);
    function getIsLocalOperator(address owner, address operator) external view returns (bool);
    function getLiquidationSpread() external view returns (D256 memory);
    function getLiquidationSpreadForPair(
        uint256 heldMarketId,
        uint256 owedMarketId
    )
        external
        view
        returns (D256 memory);
    function getMarginRatio() external view returns (D256 memory);
    function getMarket(uint256 marketId) external view returns (Market memory);
    function getMarketCachedIndex(uint256 marketId) external view returns (Index memory);
    function getMarketCurrentIndex(uint256 marketId) external view returns (Index memory);
    function getMarketIdByTokenAddress(address token) external view returns (uint256);
    function getMarketInterestRate(uint256 marketId) external view returns (Rate memory);
    function getMarketInterestSetter(uint256 marketId) external view returns (address);
    function getMarketIsClosing(uint256 marketId) external view returns (bool);
    function getMarketIsRecyclable(uint256 marketId) external view returns (bool);
    function getMarketMarginPremium(uint256 marketId) external view returns (D256 memory);
    function getMarketMaxWei(uint256 marketId) external view returns (Wei memory);
    function getMarketPrice(uint256 marketId) external view returns (Price memory);
    function getMarketPriceOracle(uint256 marketId) external view returns (address);
    function getMarketSpreadPremium(uint256 marketId) external view returns (D256 memory);
    function getMarketTokenAddress(uint256 marketId) external view returns (address);
    function getMarketTotalPar(uint256 marketId) external view returns (TotalPar memory);
    function getMarketWithInfo(uint256 marketId)
        external
        view
        returns (Market memory, Index memory, Price memory, Rate memory);
    function getMinBorrowedValue() external view returns (Value memory);
    function getNumExcessTokens(uint256 marketId) external view returns (Wei memory);
    function getNumMarkets() external view returns (uint256);
    function getRecyclableMarkets(uint256 n) external view returns (uint256[] memory);
    function getRiskLimits() external view returns (RiskLimits memory);
    function getRiskParams() external view returns (RiskParams memory);
    function isOwner() external view returns (bool);
    function operate(Info[] memory accounts, ActionArgs[] memory actions) external;
    function owner() external view returns (address);
    function ownerAddMarket(
        address token,
        address priceOracle,
        address interestSetter,
        D256 memory marginPremium,
        D256 memory spreadPremium,
        uint256 maxWei,
        bool isClosing,
        bool isRecyclable
    )
        external;
    function ownerRemoveMarkets(uint256[] memory marketIds, address salvager) external;
    function ownerSetAccountMaxNumberOfMarketsWithBalances(uint256 accountMaxNumberOfMarketsWithBalances) external;
    function ownerSetAutoTraderSpecial(address autoTrader, bool special) external;
    function ownerSetEarningsRate(D256 memory earningsRate) external;
    function ownerSetGlobalOperator(address operator, bool approved) external;
    function ownerSetInterestSetter(uint256 marketId, address interestSetter) external;
    function ownerSetIsClosing(uint256 marketId, bool isClosing) external;
    function ownerSetLiquidationSpread(D256 memory spread) external;
    function ownerSetMarginPremium(uint256 marketId, D256 memory marginPremium) external;
    function ownerSetMarginRatio(D256 memory ratio) external;
    function ownerSetMaxWei(uint256 marketId, uint256 maxWei) external;
    function ownerSetMinBorrowedValue(Value memory minBorrowedValue) external;
    function ownerSetPriceOracle(uint256 marketId, address priceOracle) external;
    function ownerSetSpreadPremium(uint256 marketId, D256 memory spreadPremium) external;
    function ownerWithdrawExcessTokens(uint256 marketId, address recipient) external returns (uint256);
    function ownerWithdrawUnsupportedTokens(address token, address recipient) external returns (uint256);
    function renounceOwnership() external;
    function setOperators(OperatorArg[] memory args) external;
    function transferOwnership(address newOwner) external;
}
