// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { PRBTest } from "@prb/test/PRBTest.sol";
import { console2 } from "forge-std/console2.sol";
import { StdCheats } from "forge-std/StdCheats.sol";

import "src/utils/FunctionCodec.sol";

contract FunctionCodecTest is PRBTest, StdCheats {
    function mockCallback(address, address, IERC20, uint256, uint256, bytes memory) external pure returns(bytes memory) {
        return "Hello, world!";
     }

    function test_encodeParams() public {
        assertEq(
            FunctionCodec.encodeParams(address(this), this.mockCallback.selector),
            bytes24(abi.encodePacked(address(this), this.mockCallback.selector))
        );
    }

    function test_decodeParams() public {
        bytes24 encoded = FunctionCodec.encodeParams(address(this), this.mockCallback.selector);
        (address contractAddr, bytes4 selector) = FunctionCodec.decodeParams(encoded);
        assertEq(contractAddr, address(this));
        assertEq(selector, this.mockCallback.selector);
    }

    function test_encodeFunction() public {
        bytes24 encoded = FunctionCodec.encodeFunction(this.mockCallback);
        assertEq(encoded, bytes24(abi.encodePacked(address(this), this.mockCallback.selector)));
    }

    function test_decodeFunction() public {
        function(address, address, IERC20, uint256, uint256, bytes memory) external returns (bytes memory) f = FunctionCodec.decodeFunction(address(this), this.mockCallback.selector);

        address a = address(1);
        IERC20 i = IERC20(a);
        uint256 u = 1;
        bytes memory b = "1";
        assertEq(f(a, a, i, u, u, b), this.mockCallback(a, a, i, u, u, b));
    }

    function test_decodeFunction2() public {
        bytes24 encoded = FunctionCodec.encodeFunction(this.mockCallback);
        function(address, address, IERC20, uint256, uint256, bytes memory) external returns (bytes memory) f = FunctionCodec.decodeFunction(encoded);

        address a = address(1);
        IERC20 i = IERC20(a);
        uint256 u = 1;
        bytes memory b = "1";
        assertEq(f(a, a, i, u, u, b), this.mockCallback(a, a, i, u, u, b));
    }
}