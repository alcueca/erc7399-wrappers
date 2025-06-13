// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import { EulerWrapper } from "../src/euler/EulerWrapper.sol";
import { IEVKFactoryPerspective } from "../src/euler/interfaces/IEVKFactoryPerspective.sol";
import { CommonBase } from "forge-std/Base.sol";
import { Script } from "forge-std/Script.sol";
import { StdChains } from "forge-std/StdChains.sol";
import { StdCheatsSafe } from "forge-std/StdCheats.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
import { console2 } from "forge-std/console2.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract EulerDeploy is Script {
    enum ChainToDeploy {
        Ethereum,
        Base,
        Berachain
    }

    ChainToDeploy internal chainToDeploy = ChainToDeploy.Berachain;

    // see https://github.com/euler-xyz/euler-interfaces/tree/master/addresses
    address internal constant EVK_FACTORY_PERSPECTIVE_ETH = 0xB30f23bc5F93F097B3A699f71B0b1718Fc82e182;
    address internal constant EVK_FACTORY_PERSPECTIVE_BASE = 0xFEA8e8a4d7ab8C517c3790E49E92ED7E1166F651;
    address internal constant EVK_FACTORY_PERSPECTIVE_BERA = 0xEE0CA74F3c60B7e1366e6d64AE2426E5177145cf;

    function run() public {
        console2.log("Deploying as %s", msg.sender);

        vm.startBroadcast();
        EulerWrapper wrapper;
        if (chainToDeploy == ChainToDeploy.Berachain) {
            wrapper = new EulerWrapper(IEVKFactoryPerspective(EVK_FACTORY_PERSPECTIVE_BERA));
        } else if (chainToDeploy == ChainToDeploy.Ethereum) {
            wrapper = new EulerWrapper(IEVKFactoryPerspective(EVK_FACTORY_PERSPECTIVE_ETH));
        } else if (chainToDeploy == ChainToDeploy.Base) {
            wrapper = new EulerWrapper(IEVKFactoryPerspective(EVK_FACTORY_PERSPECTIVE_BASE));
        } else {
            revert("Undefined chain");
        }
        console2.log("Euler deployed at: %s", address(wrapper));
        vm.stopBroadcast();
    }
}
