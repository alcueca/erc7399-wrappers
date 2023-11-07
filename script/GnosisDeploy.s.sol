// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <=0.9.0;

import { BaseScript } from "./Base.s.sol";
import { console2 } from "forge-std/console2.sol";

import { AaveWrapper } from "../src/aave/AaveWrapper.sol";
import { IPoolAddressesProviderV3 } from "../src/aave/interfaces/IPoolAddressesProviderV3.sol";
import { IPoolAddressesProviderV2 } from "../src/aave/interfaces/IPoolAddressesProviderV2.sol";
import { IPoolDataProvider } from "../src/aave/interfaces/IPoolDataProvider.sol";
import { BalancerWrapper, IFlashLoaner } from "../src/balancer/BalancerWrapper.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract GnosisDeploy is BaseScript {
    bytes32 public constant SALT = keccak256("ERC7399-wrappers");

    IFlashLoaner internal balancer = IFlashLoaner(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

    IPoolAddressesProviderV3 internal sparkProvider =
        IPoolAddressesProviderV3(0xA98DaCB3fC964A6A0d2ce3B77294241585EAbA6d);
    IPoolAddressesProviderV2 internal agaveProvider =
        IPoolAddressesProviderV2(0x3673C22153E363B1da69732c4E0aA71872Bbb87F);
    IPoolDataProvider internal agaveDataProvider = IPoolDataProvider(0xE6729389DEa76D47b5BcB0bA5c080821c3B51329);

    function run() public broadcast("https://rpc.gnosischain.com") {
        console2.log("Deploying as %s", msg.sender);

        BalancerWrapper balancerWrapper = new BalancerWrapper{salt: SALT}(balancer);
        console2.log("BalancerWrapper deployed at: %s", address(balancerWrapper));

        AaveWrapper sparkWrapper =
        new AaveWrapper{salt: SALT}(sparkProvider.getPool(), address(sparkProvider), sparkProvider.getPoolDataProvider(), false);
        console2.log("AaveWrapper (Spark) deployed at: %s", address(sparkWrapper));

        AaveWrapper agaveWrapper =
            new AaveWrapper{salt: SALT}(agaveProvider.getLendingPool(), address(agaveProvider), agaveDataProvider, true);
        console2.log("AaveWrapper (Agave) deployed at: %s", address(agaveWrapper));
    }
}
