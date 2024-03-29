// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <=0.9.0;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";

import "./Network.sol";

import { Registry } from "src/Registry.sol";

import { UniswapV3Wrapper } from "../src/uniswapV3/UniswapV3Wrapper.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract UniswapV3Deploy is Script {
    bytes32 public constant SALT = keccak256("ultrasecr.eth");

    mapping(Network network => mapping(bytes32 token => address)) public tokens;

    Registry internal registry = Registry(0xa348320114210b8F4eaF1b0795aa8F70803a93EA);
    address internal factory = 0x1F98431c8aD98523631AE4a59f267346ea31F984;

    constructor() {
        tokens[MAINNET]["USDC"] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        tokens[MAINNET]["USDT"] = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
        tokens[MAINNET]["WETH"] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        tokens[ARBITRUM]["USDC"] = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
        tokens[ARBITRUM]["USDT"] = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
        tokens[ARBITRUM]["WETH"] = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
        tokens[POLYGON]["USDC"] = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
        tokens[POLYGON]["USDT"] = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
        tokens[POLYGON]["WETH"] = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
        tokens[OPTIMISM]["USDC"] = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
        tokens[OPTIMISM]["USDT"] = 0x94b008aA00579c1307B0EF2c499aD98a8ce58e58;
        tokens[OPTIMISM]["WETH"] = 0x4200000000000000000000000000000000000006;
    }

    function run() public {
        console2.log("Deploying as %s", msg.sender);

        Network network = currentNetwork();

        bytes memory paramsBytes =
            abi.encode(factory, tokens[network]["WETH"], tokens[network]["USDC"], tokens[network]["USDT"]);

        string memory key = "UniswapV3Wrapper";

        if (keccak256(registry.get(key)) != keccak256(paramsBytes)) {
            console2.log("Updating registry");
            vm.broadcast();
            registry.set(key, paramsBytes);
        }

        (address _factory, address _weth, address _usdc, address _usdt) =
            abi.decode(registry.get(key), (address, address, address, address));
        console2.log("Factory: %s", _factory);
        console2.log("WETH: %s", _weth);
        console2.log("USDC: %s", _usdc);
        console2.log("USDT: %s", _usdt);

        vm.broadcast();
        UniswapV3Wrapper uniswapV3Wrapper = new UniswapV3Wrapper{ salt: SALT }(registry);
        console2.log("UniswapV3Wrapper deployed at: %s", address(uniswapV3Wrapper));
    }
}
