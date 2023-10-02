// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <=0.9.0;

import { BaseScript } from "./Base.s.sol";
import { console2 } from "forge-std/console2.sol";

import { Registry } from "lib/registry/src/Registry.sol";

import { UniswapV3Wrapper } from "../src/uniswapV3/UniswapV3Wrapper.sol";
import { AaveWrapper, IPoolAddressesProvider } from "../src/aave/AaveWrapper.sol";
import { BalancerWrapper, IFlashLoaner } from "../src/balancer/BalancerWrapper.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract OptimismDeploy is BaseScript {
    bytes32 public constant SALT = keccak256("ERC7399-wrappers");

    address internal factory = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    address internal usdc = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
    address internal usdt = 0x94b008aA00579c1307B0EF2c499aD98a8ce58e58;
    address internal weth = 0x4200000000000000000000000000000000000006;

    IFlashLoaner internal balancer = IFlashLoaner(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

    IPoolAddressesProvider internal provider = IPoolAddressesProvider(0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb);

    function run() public broadcast("https://optimism.llamarpc.com") {
        console2.log("Deploying as %s", msg.sender);

        Registry registry = new Registry{salt: SALT}(msg.sender);

        console2.log("Registry deployed at: %s", address(registry));

        registry.set("UniswapV3Wrapper", abi.encode(factory, weth, usdc, usdt));
        UniswapV3Wrapper uniswapV3Wrapper = new UniswapV3Wrapper{salt: SALT}(registry);
        console2.log("UniswapV3Wrapper deployed at: %s", address(uniswapV3Wrapper));

        BalancerWrapper balancerWrapper = new BalancerWrapper{salt: SALT}(balancer);
        console2.log("BalancerWrapper deployed at: %s", address(balancerWrapper));

        AaveWrapper aaveWrapper = new AaveWrapper{salt: SALT}(provider);
        console2.log("AaveWrapper deployed at: %s", address(aaveWrapper));
    }
}
