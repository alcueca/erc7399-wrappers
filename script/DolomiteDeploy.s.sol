// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <=0.9.0;

import { Script } from "forge-std/Script.sol";

import { console2 } from "forge-std/console2.sol";

import { DolomiteWrapper, IDolomiteMargin } from "../src/dolomite/DolomiteWrapper.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract DolomiteDeploy is Script {
    bytes32 public constant SALT = keccak256("ultrasecr.eth");
    IDolomiteMargin internal dolomite = IDolomiteMargin(0x6Bd780E7fDf01D77e4d475c821f1e7AE05409072);

    function run() public {
        console2.log("Deploying as %s", msg.sender);

        vm.startBroadcast();

        console2.log("Dolomite: %s", address(dolomite));
        DolomiteWrapper balancerWrapper = new DolomiteWrapper{ salt: SALT }(dolomite);
        console2.log("DolomiteWrapper deployed at: %s", address(balancerWrapper));

        vm.stopBroadcast();
    }
}
