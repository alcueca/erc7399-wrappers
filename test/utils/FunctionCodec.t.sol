// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { PRBTest } from "@prb/test/PRBTest.sol";
import { console2 } from "forge-std/console2.sol";
import { StdCheats } from "forge-std/StdCheats.sol";

import "src/utils/FunctionCodec.sol";

contract FunctionCodecTest is PRBTest, StdCheats {
    function mockCallback() external pure returns(string memory) {
        return "Hello, world!";
     }

    function testEncodeParams() public {
        assertEq(
            FunctionCodec.encodeParams(address(this), this.mockCallback.selector),
            bytes24(abi.encodePacked(address(this), this.mockCallback.selector))
        );
    }

    function testDecodeParams() public {
        bytes24 encoded = FunctionCodec.encodeParams(address(this), this.mockCallback.selector);
        (address contractAddr, bytes4 selector) = FunctionCodec.decodeParams(encoded);
        assertEq(contractAddr, address(this));
        assertEq(selector, this.mockCallback.selector);
    }

    function testEncodeFunction() public {
        bytes24 encoded = FunctionCodec.encodeFunction(this.mockCallback);
        assertEq(encoded, bytes24(abi.encodePacked(address(this), this.mockCallback.selector)));
    }

    function testDecodeFunction() public {
        function () external returns(string memory) f = FunctionCodec.decodeFunction(address(this), this.mockCallback.selector);
        assertEq(f(), this.mockCallback());
    }

    function testDecodeFunction2() public {
        bytes24 encoded = FunctionCodec.encodeFunction(this.mockCallback);
        function () external returns(string memory) f = FunctionCodec.decodeFunction(encoded);
        assertEq(f(), this.mockCallback());
    }
}
