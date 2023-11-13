// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <=0.9.0;

import { BaseScript } from "./Base.s.sol";
import { console2 } from "forge-std/console2.sol";

import { AaveWrapper } from "../src/aave/AaveWrapper.sol";
import { IPoolAddressesProviderV3 } from "../src/aave/interfaces/IPoolAddressesProviderV3.sol";
import { BalancerWrapper, IFlashLoaner } from "../src/balancer/BalancerWrapper.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract GnosisDeploy is BaseScript {
    bytes32 public constant SALT = keccak256("ERC7399-wrappers");

    IFlashLoaner internal balancer = IFlashLoaner(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

    IPoolAddressesProviderV3 internal aaveProvider =
        IPoolAddressesProviderV3(0xe20fCBdBfFC4Dd138cE8b2E6FBb6CB49777ad64D);

    function run() public broadcast("https://base.llamarpc.com") {
        console2.log("Deploying as %s", msg.sender);

        BalancerWrapper balancerWrapper = new BalancerWrapper{salt: SALT}(balancer);
        console2.log("BalancerWrapper deployed at: %s", address(balancerWrapper));

        AaveWrapper aaveWrapper =
        new AaveWrapper{salt: SALT}(aaveProvider.getPool(), address(aaveProvider), aaveProvider.getPoolDataProvider(), false);
        console2.log("AaveWrapper (aave) deployed at: %s", address(aaveWrapper));
    }
}
