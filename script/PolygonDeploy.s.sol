// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <=0.9.0;

import { BaseScript } from "./Base.s.sol";
import { console2 } from "forge-std/console2.sol";

import { Registry } from "lib/registry/src/Registry.sol";

import { UniswapV3Wrapper } from "../src/uniswapV3/UniswapV3Wrapper.sol";
import { AaveWrapper } from "../src/aave/AaveWrapper.sol";
import { IPoolAddressesProviderV3 } from "../src/aave/interfaces/IPoolAddressesProviderV3.sol";
import { IPoolAddressesProviderV2 } from "../src/aave/interfaces/IPoolAddressesProviderV2.sol";
import { IPoolDataProvider } from "../src/aave/interfaces/IPoolDataProvider.sol";
import { BalancerWrapper, IFlashLoaner } from "../src/balancer/BalancerWrapper.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract PolygonDeploy is BaseScript {
    bytes32 public constant SALT = keccak256("ERC7399-wrappers");

    address internal factory = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    address internal usdc = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address internal usdt = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
    address internal weth = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;

    IFlashLoaner internal balancer = IFlashLoaner(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

    IPoolAddressesProviderV3 internal providerV3 = IPoolAddressesProviderV3(0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb);
    IPoolAddressesProviderV2 internal providerV2 = IPoolAddressesProviderV2(0xd05e3E715d945B59290df0ae8eF85c1BdB684744);
    IPoolDataProvider internal dataProviderV2 = IPoolDataProvider(0x7551b5D2763519d4e37e8B81929D336De671d46d);

    function run() public broadcast("https://polygon.llamarpc.com") {
        console2.log("Deploying as %s", msg.sender);

        Registry registry = new Registry{salt: SALT}(msg.sender);

        console2.log("Registry deployed at: %s", address(registry));

        registry.set("UniswapV3Wrapper", abi.encode(factory, weth, usdc, usdt));
        UniswapV3Wrapper uniswapV3Wrapper = new UniswapV3Wrapper{salt: SALT}(registry);
        console2.log("UniswapV3Wrapper deployed at: %s", address(uniswapV3Wrapper));

        BalancerWrapper balancerWrapper = new BalancerWrapper{salt: SALT}(balancer);
        console2.log("BalancerWrapper deployed at: %s", address(balancerWrapper));

        AaveWrapper aaveV3Wrapper =
        new AaveWrapper{salt: SALT}(providerV3.getPool(), address(providerV3), providerV3.getPoolDataProvider(), false);
        console2.log("AaveWrapper (V3) deployed at: %s", address(aaveV3Wrapper));

        AaveWrapper aaveV2Wrapper =
            new AaveWrapper{salt: SALT}(providerV2.getLendingPool(), address(providerV2), dataProviderV2, true);
        console2.log("AaveWrapper (V2) deployed at: %s", address(aaveV2Wrapper));
    }
}
