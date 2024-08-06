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

function _equals(Network a, Network b) pure returns (bool) {
    return Network.unwrap(a) == Network.unwrap(b);
}

function _ne(Network a, Network b) pure returns (bool) {
    return !_equals(a, b);
}

using { toString, _equals as ==, _ne as != } for Network global;

function toString(Network n) pure returns (string memory) {
    if (n == MAINNET) return "Ethereum";
    if (n == OPTIMISM) return "Optimism";
    if (n == GNOSIS) return "Gnosis";
    if (n == POLYGON) return "Polygon";
    if (n == BASE) return "Base";
    if (n == ARBITRUM) return "Arbitrum-One";
    if (n == BSC) return "Binance Smart Chain";
    if (n == AVALANCHE) return "Avalanche C-Chain";
    if (n == SCROLL) return "Scroll";
    revert("Unknown network");
}
