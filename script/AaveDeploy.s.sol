// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <=0.9.0;

import { Script } from "forge-std/Script.sol";

import { console2 } from "forge-std/console2.sol";

import { AaveWrapper, IPoolAddressesProvider } from "../src/aave/AaveWrapper.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract AaveDeploy is Script {
    enum Network {
        MAINNET,
        ARBITRUM,
        POLYGON,
        OPTIMISM
    }
    bytes32 public constant SALT = keccak256("alcueca-1");
    Network public constant NETWORK = Network.MAINNET;

    mapping(Network network => IPoolAddressesProvider) public providers;

    address internal factory = 0x1F98431c8aD98523631AE4a59f267346ea31F984;

    constructor () {
        providers[Network.MAINNET] = IPoolAddressesProvider(0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e);
        providers[Network.ARBITRUM] = IPoolAddressesProvider(0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb);
        providers[Network.POLYGON] = IPoolAddressesProvider(0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb);
        providers[Network.OPTIMISM] = IPoolAddressesProvider(0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb);
    }


    IPoolAddressesProvider internal provider = IPoolAddressesProvider(0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e);


    function run() public {
        console2.log("Deploying as %s", msg.sender);

        vm.startBroadcast();

        console2.log("Aave: %s", address(providers[NETWORK]));
        AaveWrapper aaveWrapper = new AaveWrapper{salt: SALT}(providers[NETWORK]);
        console2.log("AaveWrapper deployed at: %s", address(aaveWrapper));

        vm.stopBroadcast();
    }
}
