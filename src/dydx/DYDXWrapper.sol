// SPDX-License-Identifier: GPL-3.0-or-later
// Derived from https://github.com/kollateral/kollateral/blob/master/protocol/contracts/liquidity/kollateral/KollateralLiquidityProxy.sol
pragma solidity ^0.8.0;

import { SoloMarginLike } from "./interfaces/SoloMarginLike.sol";
import { DYDXFlashBorrowerLike } from "./interfaces/DYDXFlashBorrowerLike.sol";
import { DYDXDataTypes } from "./libraries/DYDXDataTypes.sol";
import { RevertMsgExtractor } from "../utils/RevertMsgExtractor.sol";
import { FunctionCodec } from "../utils/FunctionCodec.sol";

import { IERC20 } from "lib/erc3156pp/src/interfaces/IERC20.sol";
import { IERC3156PPFlashLender } from "lib/erc3156pp/src/interfaces/IERC3156PPFlashLender.sol";


library TransferHelper {
    /// @notice Transfers tokens from msg.sender to a recipient
    /// @dev Errors with the underlying revert message if transfer fails
    /// @param token The contract address of the token which will be transferred
    /// @param to The recipient of the transfer
    /// @param value The value of the transfer
    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(IERC20.transfer.selector, to, value));
        if (!(success && (data.length == 0 || abi.decode(data, (bool))))) revert(RevertMsgExtractor.getRevertMsg(data));
    }
}


contract DYDXWrapper is IERC3156PPFlashLender, DYDXFlashBorrowerLike {
    using TransferHelper for IERC20;
    using FunctionCodec for function(address, address, IERC20, uint256, uint256, bytes memory) external returns (bytes memory);
    using FunctionCodec for bytes24;

    uint256 internal NULL_ACCOUNT_ID = 0;
    uint256 internal NULL_MARKET_ID = 0;
    DYDXDataTypes.AssetAmount internal NULL_AMOUNT = DYDXDataTypes.AssetAmount({
        sign: false,
        denomination: DYDXDataTypes.AssetDenomination.Wei,
        ref: DYDXDataTypes.AssetReference.Delta,
        value: 0
    });
    bytes internal NULL_DATA = "";
    bytes internal _callbackResult;

    SoloMarginLike public soloMargin;
    mapping(IERC20 => uint256) public assetAddressToMarketId;
    mapping(IERC20 => bool) public assetsRegistered;

    /// @param soloMargin_ DYDX SoloMargin address
    constructor (SoloMarginLike soloMargin_) {
        soloMargin = soloMargin_;

        for (uint256 marketId = 0; marketId <= 3; marketId++) {
            IERC20 asset = IERC20(soloMargin.getMarketTokenAddress(marketId));
            assetAddressToMarketId[asset] = marketId;
            assetsRegistered[asset] = true;
        }
    }

    /**
     * @dev From ERC-3156++. The fee to be charged for a given loan.
     * @param asset The loan currency.
     * @param amount The amount of assets lent.
     * @return The amount of `asset` to be charged for the loan, on top of the returned principal.
     */
    function flashFee(IERC20 asset, uint256 amount) public view returns (uint256) {
        require(assetsRegistered[asset], "Unsupported currency");
        return (amount <= asset.balanceOf(address(soloMargin))) ? 2 : type(uint256).max;
    }

    /// @dev Use the aggregator to serve an ERC3156++ flash loan.
    /// @dev Forward the callback to the callback receiver. The borrower only needs to trust the aggregator and its governance, instead of the underlying lenders.
    /// @param loanReceiver The address receiving the flash loan
    /// @param asset The asset to be loaned
    /// @param amount The amount to loaned
    /// @param initiatorData The ABI encoded initiator data
    /// @param callback The address and signature of the callback function
    /// @return result ABI encoded result of the callback
    function flashLoan(
        address loanReceiver,
        IERC20 asset,
        uint256 amount,
        bytes calldata initiatorData,
        /// @dev callback.
        /// This is a concatenation of (address, bytes4), where the address is the callback receiver, and the bytes4 is the signature of callback function.
        /// The arguments in the callback function are fixed.
        /// If the callback receiver needs to know the loan receiver, it should be encoded by the initiator in `data`.
        /// @param initiator The address that called this function
        /// @param paymentReceiver The address that needs to receive the amount plus fee at the end of the callback
        /// @param asset The asset to be loaned
        /// @param amount The amount to loaned
        /// @param fee The fee to be paid
        /// @param data The ABI encoded data to be passed to the callback
        /// @return result ABI encoded result of the callback
        function(address, address, IERC20, uint256, uint256, bytes memory) external returns (bytes memory) callback
    ) external returns (bytes memory) {
        DYDXDataTypes.ActionArgs[] memory operations = new DYDXDataTypes.ActionArgs[](3);
        operations[0] = getWithdrawAction(loanReceiver, asset, amount);
        operations[1] = getCallAction(abi.encode(msg.sender, asset, amount, callback.encodeFunction(), initiatorData));
        operations[2] = getDepositAction(asset, amount + flashFee(asset, amount));
        DYDXDataTypes.AccountInfo[] memory accountInfos = new DYDXDataTypes.AccountInfo[](1);
        accountInfos[0] = getAccountInfo();

        soloMargin.operate(accountInfos, operations);

        bytes memory result = _callbackResult;
        _callbackResult = ""; // TODO: Confirm that this deletes the storage variable
        return result;
    }

    /// @dev DYDX flash loan callback. It sends the value borrowed to `receiver`, and takes it back plus a `flashFee` after the ERC3156 callback.
    function callFunction(
        address sender,
        DYDXDataTypes.AccountInfo memory,
        bytes memory data
    )
    public override
    {
        require(msg.sender == address(soloMargin), "Callback only from SoloMargin");
        require(sender == address(this), "FlashLoan only from this contract");

        // We pass the loan to the loan receiver and we store the callback result in storage for the the ERC3156++ flashLoan function to recover it.
        _callbackResult = _callFromData(data);
    }


    /// @dev Internal function to transfer to the loan receiver and the callback. It is used to avoid stack too deep.
    function _callFromData(bytes memory data) internal returns(bytes memory) {
        (address initiator, IERC20 asset, uint256 amount, bytes24 encodedCallback, bytes memory initiatorData) = 
            abi.decode(data, (address, IERC20, uint256, bytes24, bytes));

        uint256 fee = flashFee(asset, amount);

        function(address, address, IERC20, uint256, uint256, bytes memory) external returns (bytes memory) callback = encodedCallback.decodeFunction();
        
        // Approve the SoloMargin contract allowance to *pull* the owed amount
        IERC20(asset).approve(address(soloMargin), amount + fee);            

        return callback(initiator, address(this), asset, amount, fee, initiatorData);
    }

    function getAccountInfo() internal view returns (DYDXDataTypes.AccountInfo memory) {
        return DYDXDataTypes.AccountInfo({
            owner: address(this),
            number: 1
        });
    }

    function getWithdrawAction(address loanReceiver, IERC20 asset,uint256 amount)
    internal
    view
    returns (DYDXDataTypes.ActionArgs memory)
    {
        return DYDXDataTypes.ActionArgs({
            actionType: DYDXDataTypes.ActionType.Withdraw,
            accountId: 0,
            amount: DYDXDataTypes.AssetAmount({
                sign: false,
                denomination: DYDXDataTypes.AssetDenomination.Wei,
                ref: DYDXDataTypes.AssetReference.Delta,
                value: amount
            }),
            primaryMarketId: assetAddressToMarketId[asset],
            secondaryMarketId: NULL_MARKET_ID,
            otherAddress: loanReceiver,
            otherAccountId: NULL_ACCOUNT_ID,
            data: NULL_DATA
        });
    }

    function getDepositAction(IERC20 asset, uint256 repaymentAmount)
    internal
    view
    returns (DYDXDataTypes.ActionArgs memory)
    {
        return DYDXDataTypes.ActionArgs({
            actionType: DYDXDataTypes.ActionType.Deposit,
            accountId: 0,
            amount: DYDXDataTypes.AssetAmount({
                sign: true,
                denomination: DYDXDataTypes.AssetDenomination.Wei,
                ref: DYDXDataTypes.AssetReference.Delta,
                value: repaymentAmount
            }),
            primaryMarketId: assetAddressToMarketId[asset],
            secondaryMarketId: NULL_MARKET_ID,
            otherAddress: address(this),
            otherAccountId: NULL_ACCOUNT_ID,
            data: NULL_DATA
        });
    }

    function getCallAction(bytes memory data_)
    internal
    view
    returns (DYDXDataTypes.ActionArgs memory)
    {
        return DYDXDataTypes.ActionArgs({
            actionType: DYDXDataTypes.ActionType.Call,
            accountId: 0,
            amount: NULL_AMOUNT,
            primaryMarketId: NULL_MARKET_ID,
            secondaryMarketId: NULL_MARKET_ID,
            otherAddress: address(this),
            otherAccountId: NULL_ACCOUNT_ID,
            data: data_
        });
    }
}