// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

type Network is uint256;

Network constant MAINNET = Network.wrap(1);
Network constant OPTIMISM = Network.wrap(10);
Network constant GNOSIS = Network.wrap(100);
Network constant POLYGON = Network.wrap(137);
Network constant BASE = Network.wrap(8453);
Network constant ARBITRUM = Network.wrap(42_161);
Network constant BSC = Network.wrap(56);
Network constant AVALANCHE = Network.wrap(43_114);
Network constant SCROLL = Network.wrap(534_352);

function currentNetwork() view returns (Network) {
    return Network.wrap(block.chainid);
}

function toString(Network n) pure returns (string memory) {
    if (Network.unwrap(n) == Network.unwrap(MAINNET)) return "Ethereum";
    if (Network.unwrap(n) == Network.unwrap(OPTIMISM)) return "Optimism";
    if (Network.unwrap(n) == Network.unwrap(GNOSIS)) return "Gnosis";
    if (Network.unwrap(n) == Network.unwrap(POLYGON)) return "Polygon";
    if (Network.unwrap(n) == Network.unwrap(BASE)) return "Base";
    if (Network.unwrap(n) == Network.unwrap(ARBITRUM)) return "Arbitrum-One";
    if (Network.unwrap(n) == Network.unwrap(BSC)) return "Binance Smart Chain";
    if (Network.unwrap(n) == Network.unwrap(AVALANCHE)) return "Avalanche C-Chain";
    if (Network.unwrap(n) == Network.unwrap(SCROLL)) return "Scroll";
    revert("Unknown network");
}

using { toString } for Network global;
