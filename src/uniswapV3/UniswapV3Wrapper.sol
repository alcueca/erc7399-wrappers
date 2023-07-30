// SPDX-License-Identifier: GPL-3.0-or-later
// Thanks to sunnyRK and yashnaman
pragma solidity ^0.8.0;

import { IUniswapV3FlashCallback } from "./interfaces/callback/IUniswapV3FlashCallback.sol";
import { IUniswapV3Pool } from "./interfaces/IUniswapV3Pool.sol";
import { IUniswapV3Factory } from "./interfaces/IUniswapV3Factory.sol";

import { TransferHelper } from "../utils/TransferHelper.sol";

import { IERC20 } from "lib/erc3156pp/src/interfaces/IERC20.sol";
import { IERC3156PPFlashLender } from "lib/erc3156pp/src/interfaces/IERC3156PPFlashLender.sol";

contract UniswapV3Wrapper is IERC3156PPFlashLender, IUniswapV3FlashCallback {
    using TransferHelper for IERC20;

    struct Data {
        address loanReceiver;
        address initiator;
        function(address, address, IERC20, uint256, uint256, bytes memory) external returns (bytes memory) callback;
        bytes initiatorData;
    }

    // CONSTANTS
    IUniswapV3Factory public immutable factory;

    // ACCESS CONTROL
    IUniswapV3Pool internal _activePool;
    bytes internal _callbackResult;

    // DEFAULT ASSETS
    IERC20 weth;
    IERC20 dai;

    /// @param factory_ Uniswap v3 UniswapV3Factory address
    /// @param weth_ Weth contract used in Uniswap v3 Pairs
    /// @param dai_ dai contract used in Uniswap v3 Pairs
    constructor(IUniswapV3Factory factory_, IERC20 weth_, IERC20 dai_) {
        factory = factory_;
        weth = weth_;
        dai = dai_;
    }

    /**
     * @dev Get the Uniswap Pool that will be used as the source of a loan. The opposite asset will be Weth, except for
     * Weth that will be Dai.
     * @param asset The loan currency.
     * @return The Uniswap V3 Pool that will be used as the source of the flash loan.
     */
    function getPool(IERC20 asset) public view returns (IUniswapV3Pool) {
        IERC20 assetOther = asset == weth ? dai : weth;
        return IUniswapV3Pool(factory.getPool(address(asset), address(assetOther), 3000));
    }

    /**
     * @dev From ERC-3156. The fee to be charged for a given loan.
     * @param asset The loan currency.
     * @param amount The amount of assets lent.
     * @return The amount of `asset` to be charged for the loan, on top of the returned principal.
     */
    function flashFee(IERC20 asset, uint256 amount) public view override returns (uint256) {
        IUniswapV3Pool pool = getPool(asset);
        if (asset.balanceOf(address(pool)) < amount) return type(uint256).max;
        return amount * uint256(pool.fee()) / 1e6;
    }

    /// @dev Use the aggregator to serve an ERC3156++ flash loan.
    /// @dev Forward the callback to the callback receiver. The borrower only needs to trust the aggregator and its
    /// governance, instead of the underlying lenders.
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
        /// This is a concatenation of (address, bytes4), where the address is the callback receiver, and the bytes4 is
        /// the signature of callback function.
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
    )
        external
        returns (bytes memory)
    {
        IUniswapV3Pool pool = getPool(asset);
        require(address(pool) != address(0), "Unsupported currency");

        IERC20 asset0 = IERC20(pool.token0());
        IERC20 asset1 = IERC20(pool.token1());
        uint256 amount0 = asset == asset0 ? amount : 0;
        uint256 amount1 = asset == asset1 ? amount : 0;

        bytes memory data = abi.encode(
            Data({ loanReceiver: loanReceiver, initiator: msg.sender, callback: callback, initiatorData: initiatorData })
        );

        _activePool = pool;
        pool.flash(address(this), amount0, amount1, data);
        delete _activePool;

        bytes memory result = _callbackResult;
        delete _callbackResult; // TODO: Confirm that this deletes the storage variable
        return result;
    }

    // Flashswap Callback
    function uniswapV3FlashCallback(
        uint256 fee0, // Fee on Asset0
        uint256 fee1, // Fee on Asset1
        bytes calldata params
    )
        external
        override
    {
        require(msg.sender == address(_activePool), "Only active pool");

        Data memory data = abi.decode(params, (Data));
        uint256 fee = fee0 > 0 ? fee0 : fee1;
        IERC20 asset = IERC20(fee0 > 0 ? IUniswapV3Pool(msg.sender).token0() : IUniswapV3Pool(msg.sender).token1());
        uint256 amount = asset.balanceOf(address(this));

        // send the borrowed amount to the loan receiver
        asset.safeTransfer(data.loanReceiver, amount);

        // call the callback and tell the calback receiver to pay to the pool contract
        // the callback result is kept in a storage variable to be retrieved later in this tx
        _callbackResult = data.callback(data.initiator, msg.sender, asset, amount, fee, data.initiatorData);
    }
}
