// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

type Network is uint256;

Network constant MAINNET = Network.wrap(1);
Network constant OPTIMISM = Network.wrap(10);
Network constant GNOSIS = Network.wrap(100);
Network constant POLYGON = Network.wrap(137);
Network constant BASE = Network.wrap(8453);
Network constant ARBITRUM = Network.wrap(42_161);

function currentNetwork() view returns (Network) {
    return Network.wrap(block.chainid);
}
