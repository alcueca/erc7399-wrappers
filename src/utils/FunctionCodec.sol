// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC20 } from "lib/erc3156pp/src/interfaces/IERC20.sol";

library FunctionCodec {
    function encodeParams(address contractAddr, bytes4 selector) internal pure returns (bytes24) {
        return bytes24(bytes20(contractAddr)) | bytes24(selector) >> 160;
    }

    function decodeParams(bytes24 encoded) internal pure returns (address contractAddr, bytes4 selector) {
        contractAddr = address(bytes20(encoded));
        selector = bytes4(encoded << 160);
    }

    function encodeFunction(
        function(address, address, IERC20, uint256, uint256, bytes memory) external returns (bytes memory) f
    )
        internal
        pure
        returns (bytes24)
    {
        return encodeParams(f.address, f.selector);
    }

    function decodeFunction(
        address contractAddr,
        bytes4 selector
    )
        internal
        pure
        returns (function(address, address, IERC20, uint256, uint256, bytes memory) external returns (bytes memory) f)
    {
        uint32 s = uint32(selector);
        assembly {
            f.address := contractAddr
            f.selector := s
        }
    }

    function decodeFunction(bytes24 encoded)
        internal
        pure
        returns (function(address, address, IERC20, uint256, uint256, bytes memory) external returns (bytes memory) f)
    {
        (address contractAddr, bytes4 selector) = decodeParams(encoded);
        return decodeFunction(contractAddr, selector);
    }
}
