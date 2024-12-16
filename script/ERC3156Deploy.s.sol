// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <=0.9.0;

import { Script } from "forge-std/Script.sol";

import { console2 } from "forge-std/console2.sol";

import "./Network.sol";

import { ERC3156Wrapper, IERC3156FlashLender } from "../src/erc3156/ERC3156Wrapper.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract ERC3156Deploy is Script {
    bytes32 public constant SALT = keccak256("ultrasecr.eth");

    struct Deployment {
        Network network;
        address[] assets;
        IERC3156FlashLender[] lenders;
    }

    Deployment[] public deployments;

    address[] noAssets;
    IERC3156FlashLender[] noLenders;

    constructor() {
        address[] memory assets = new address[](2);
        assets[0] = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        assets[1] = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f;
        IERC3156FlashLender[] memory lenders = new IERC3156FlashLender[](2);
        lenders[0] = IERC3156FlashLender(0x60744434d6339a6B27d73d9Eda62b6F66a0a04FA);
        lenders[1] = IERC3156FlashLender(0xb639D208Bcf0589D54FaC24E655C79EC529762B8);
        deployments.push(Deployment(MAINNET, assets, lenders));
        
        deployments.push(Deployment(ARBITRUM, noAssets, noLenders));
    }

    function run() public {
        console2.log("Deploying as %s", msg.sender);

        Network network = currentNetwork();

        for (uint256 i = 0; i < deployments.length; i++) {
            Deployment memory deployment = deployments[i];
            if (deployment.network != network) continue;

            require(deployment.assets.length == deployment.lenders.length, "Arrays must be the same length");

            vm.broadcast();
            ERC3156Wrapper wrapper = new ERC3156Wrapper{ salt: SALT }(deployment.assets, deployment.lenders);

            // Belt and braces
            for (uint256 j = 0; j < deployment.assets.length; j++) {
                require(wrapper.maxFlashLoan(deployment.assets[j]) > 0, "Max flash loan is zero");
                require(wrapper.flashFee(deployment.assets[j], 1e18) == 0, "Fee is not zero");
            }

            console2.log("Deployed ERC3156Wrapper at %s", address(wrapper));
        }
    }
}
