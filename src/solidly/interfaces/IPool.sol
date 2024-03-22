// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface IPool {
    struct Observation {
        uint256 timestamp;
        uint256 reserve0Cumulative;
        uint256 reserve1Cumulative;
    }

    error BelowMinimumK();
    error DepositsNotEqual();
    error FactoryAlreadySet();
    error InsufficientInputAmount();
    error InsufficientLiquidity();
    error InsufficientLiquidityBurned();
    error InsufficientLiquidityMinted();
    error InsufficientOutputAmount();
    error InvalidTo();
    error IsPaused();
    error K();
    error NotEmergencyCouncil();
    error StringTooLong(string str);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function blockTimestampLast() external view returns (uint256);
    function burn(address to) external returns (uint256 amount0, uint256 amount1);
    function claimFees() external returns (uint256 claimed0, uint256 claimed1);
    function claimable0(address) external view returns (uint256);
    function claimable1(address) external view returns (uint256);
    function currentCumulativePrices()
        external
        view
        returns (uint256 reserve0Cumulative, uint256 reserve1Cumulative, uint256 blockTimestamp);
    function decimals() external view returns (uint8);
    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool);
    function eip712Domain()
        external
        view
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        );
    function factory() external view returns (address);
    function getAmountOut(uint256 amountIn, address tokenIn) external view returns (uint256);
    function getK() external returns (uint256);
    function getReserves() external view returns (uint256 _reserve0, uint256 _reserve1, uint256 _blockTimestampLast);
    function increaseAllowance(address spender, uint256 addedValue) external returns (bool);
    function index0() external view returns (uint256);
    function index1() external view returns (uint256);
    function initialize(address _token0, address _token1, bool _stable) external;
    function lastObservation() external view returns (Observation memory);
    function metadata()
        external
        view
        returns (uint256 dec0, uint256 dec1, uint256 r0, uint256 r1, bool st, address t0, address t1);
    function mint(address to) external returns (uint256 liquidity);
    function name() external view returns (string memory);
    function nonces(address owner) external view returns (uint256);
    function observationLength() external view returns (uint256);
    function observations(uint256)
        external
        view
        returns (uint256 timestamp, uint256 reserve0Cumulative, uint256 reserve1Cumulative);
    function periodSize() external view returns (uint256);
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external;
    function poolFees() external view returns (address);
    function prices(address tokenIn, uint256 amountIn, uint256 points) external view returns (uint256[] memory);
    function quote(address tokenIn, uint256 amountIn, uint256 granularity) external view returns (uint256 amountOut);
    function reserve0() external view returns (uint256);
    function reserve0CumulativeLast() external view returns (uint256);
    function reserve1() external view returns (uint256);
    function reserve1CumulativeLast() external view returns (uint256);
    function sample(
        address tokenIn,
        uint256 amountIn,
        uint256 points,
        uint256 window
    )
        external
        view
        returns (uint256[] memory);
    function setName(string memory __name) external;
    function setSymbol(string memory __symbol) external;
    function skim(address to) external;
    function stable() external view returns (bool);
    function supplyIndex0(address) external view returns (uint256);
    function supplyIndex1(address) external view returns (uint256);
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes memory data) external;
    function symbol() external view returns (string memory);
    function sync() external;
    function token0() external view returns (address);
    function token1() external view returns (address);
    function tokens() external view returns (address, address);
    function totalSupply() external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}
