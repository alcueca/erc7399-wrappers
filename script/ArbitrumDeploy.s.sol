// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <=0.9.0;

import { BaseScript } from "./Base.s.sol";
import { console2 } from "forge-std/console2.sol";

import { Registry } from "lib/registry/src/Registry.sol";

import { UniswapV3Wrapper } from "../src/uniswapV3/UniswapV3Wrapper.sol";
import { AaveWrapper } from "../src/aave/AaveWrapper.sol";
import { IPoolAddressesProviderV3 } from "../src/aave/interfaces/IPoolAddressesProviderV3.sol";
import { BalancerWrapper, IFlashLoaner } from "../src/balancer/BalancerWrapper.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract ArbitrumDeploy is BaseScript {
    bytes32 public constant SALT = keccak256("ERC7399-wrappers");

    address internal factory = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    address internal usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal usdt = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address internal weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal wbtc = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    IFlashLoaner internal balancer = IFlashLoaner(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

    IPoolAddressesProviderV3 internal provider = IPoolAddressesProviderV3(0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb);

    function run() public broadcast("https://arbitrum.llamarpc.com") {
        console2.log("Deploying as %s", msg.sender);

        Registry registry = new Registry{salt: SALT}(msg.sender);

        console2.log("Registry deployed at: %s", address(registry));

        registry.set("UniswapV3Wrapper", abi.encode(factory, weth, usdc, usdt));
        UniswapV3Wrapper uniswapV3Wrapper = new UniswapV3Wrapper{salt: SALT}(registry);
        console2.log("UniswapV3Wrapper deployed at: %s", address(uniswapV3Wrapper));

        BalancerWrapper balancerWrapper = new BalancerWrapper{salt: SALT}(balancer);
        console2.log("BalancerWrapper deployed at: %s", address(balancerWrapper));

        AaveWrapper aaveWrapper =
            new AaveWrapper{salt: SALT}(provider.getPool(), address(provider), provider.getPoolDataProvider(), false);
        console2.log("AaveWrapper deployed at: %s", address(aaveWrapper));
    }
}
