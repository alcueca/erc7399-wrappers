// SPDX-License-Identifier: MIT
// Thanks to ultrasecr.eth
pragma solidity ^0.8.19;

import { IDolomiteMargin } from "./interfaces/IDolomiteMargin.sol";
import { ICallee } from "./interfaces/ICallee.sol";

import { Arrays } from "../utils/Arrays.sol";

import { FixedPointMathLib } from "lib/solmate/src/utils/FixedPointMathLib.sol";

import { BaseWrapper, IERC7399, ERC20 } from "../BaseWrapper.sol";

/// @dev Dolomite Flash Lender that uses DolomiteMargin as source of liquidity.
contract DolomiteWrapper is BaseWrapper, ICallee {
    using Arrays for uint256;
    using Arrays for address;
    using FixedPointMathLib for uint256;

    error NotSelf();
    error NotDolomite();
    error HashMismatch();

    IDolomiteMargin public immutable dolomite;

    bytes32 private flashLoanDataHash;

    constructor(IDolomiteMargin _dolomite) {
        dolomite = _dolomite;
    }

    /// @inheritdoc IERC7399
    function maxFlashLoan(address asset) public view returns (uint256) {
        return ERC20(asset).balanceOf(address(dolomite));
    }

    /// @inheritdoc IERC7399
    function flashFee(address asset, uint256 amount) external view returns (uint256) {
        uint256 max = maxFlashLoan(asset);
        require(max > 0, "Unsupported currency");
        // https://docs.dolomite.io/developer-documentation/flash-loans
        return amount >= max ? type(uint256).max : 0;
    }

    /// @inheritdoc ICallee
    function callFunction(
        address sender,
        IDolomiteMargin.Info memory, /* accountInfo */
        bytes memory data
    )
        external
        override
    {
        if (sender != address(this)) revert NotSelf();
        if (msg.sender != address(dolomite)) revert NotDolomite();
        if (keccak256(data) != flashLoanDataHash) revert HashMismatch();
        delete flashLoanDataHash;

        (address asset, uint256 amount, bytes memory params) = abi.decode(data, (address, uint256, bytes));

        _bridgeToCallback(asset, amount, 0, params);
    }

    function _flashLoan(address asset, uint256 amount, bytes memory data) internal override {
        bytes memory metadata = abi.encode(asset, amount, data);
        flashLoanDataHash = keccak256(metadata);

        IDolomiteMargin.Info[] memory accounts = new IDolomiteMargin.Info[](1);
        accounts[0].owner = address(this);

        uint256 marketId = dolomite.getMarketIdByTokenAddress(asset);
        IDolomiteMargin.ActionArgs[] memory actions = new IDolomiteMargin.ActionArgs[](3);

        actions[0].actionType = IDolomiteMargin.ActionType.Withdraw;
        actions[0].amount.value = amount;
        actions[0].primaryMarketId = marketId;
        actions[0].otherAddress = abi.decode(data, (Data)).loanReceiver;

        actions[1].actionType = IDolomiteMargin.ActionType.Call;
        actions[1].otherAddress = address(this);
        actions[1].data = metadata;

        actions[2].actionType = IDolomiteMargin.ActionType.Deposit;
        actions[2].amount.sign = true;
        actions[2].amount.value = amount;
        actions[2].primaryMarketId = marketId;
        actions[2].otherAddress = address(this);

        dolomite.operate(accounts, actions);
    }

    // Funds are sent directly to the loanReceiver
    function _transferAssets(address, uint256, address) internal override { }
}
