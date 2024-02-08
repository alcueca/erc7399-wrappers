// SPDX-License-Identifier: MIT
// Thanks to ultrasecr.eth
pragma solidity ^0.8.19;

import { IMorphoFlashLoanCallback } from "./interfaces/IMorphoFlashLoanCallback.sol";
import { IMorpho } from "./interfaces/IMorpho.sol";

import { BaseWrapper, IERC7399, ERC20 } from "../BaseWrapper.sol";

/// @dev MorphoBlue Flash Lender that uses MorphoBlue as source of liquidity.
contract MorphoBlueWrapper is BaseWrapper, IMorphoFlashLoanCallback {
    error NotMorpho();
    error UnsupportedAsset(address asset);

    IMorpho public immutable morpho;

    constructor(IMorpho _morpho) {
        morpho = _morpho;
    }

    /// @inheritdoc IERC7399
    function maxFlashLoan(address asset) public view returns (uint256) {
        return ERC20(asset).balanceOf(address(morpho));
    }

    /// @inheritdoc IERC7399
    function flashFee(address asset, uint256 amount) external view returns (uint256) {
        uint256 max = maxFlashLoan(asset);
        if (max == 0) revert UnsupportedAsset(asset);
        return amount >= max ? type(uint256).max : 0;
    }

    function onMorphoFlashLoan(uint256 amount, bytes calldata params) external {
        if (msg.sender != address(morpho)) revert NotMorpho();
        (address asset, bytes memory data) = abi.decode(params, (address, bytes));

        _bridgeToCallback(asset, amount, 0, data);
    }

    function _flashLoan(address asset, uint256 amount, bytes memory data) internal override {
        morpho.flashLoan(asset, amount, abi.encode(asset, data));
    }
}
