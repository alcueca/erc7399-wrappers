// SPDX-License-Identifier: MIT
// Thanks to ultrasecr.eth
pragma solidity ^0.8.19;

import { Registry } from "lib/registry/src/Registry.sol";

import { IFlashLoanRecipient } from "../balancer/interfaces/IFlashLoanRecipient.sol";
import { IFlashLoaner } from "../balancer/interfaces/IFlashLoaner.sol";
import { IComptroller, Error } from "./interfaces/IComptroller.sol";
import { ICToken } from "./interfaces/ICToken.sol";

import { Arrays } from "../utils/Arrays.sol";

import { FixedPointMathLib } from "lib/solmate/src/utils/FixedPointMathLib.sol";
import { SafeTransferLib } from "lib/solmate/src/utils/SafeTransferLib.sol";
import { WETH } from "lib/solmate/src/tokens/WETH.sol";

import { BaseWrapper, IERC7399, ERC20 } from "../BaseWrapper.sol";

/// @dev Compound Flash Lender that uses Balancer Pools as source of X liquidity,
/// then deposits X on Compound to borrow whatever's necessary.
contract CompoundWrapper is BaseWrapper, IFlashLoanRecipient {
    using Arrays for uint256;
    using Arrays for address;
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;

    event CTokenSet(ERC20 indexed asset, ICToken indexed cToken);

    error NotBalancer();
    error HashMismatch();

    error FailedToBorrow(Error _error);
    error FailedToRepay(Error _error);
    error FailedToRedeem(Error _error);
    error FailedToLend(Error _error);
    error FailedToEnterMarket(Error _error);
    error CTokenNotFound(ERC20 _asset);
    error InvalidMarket();

    IFlashLoaner public immutable balancer;
    IComptroller public immutable comptroller;
    WETH public immutable nativeToken;
    ERC20 public immutable intermediateToken;

    mapping(ERC20 token => ICToken cToken) public cTokens;

    bytes32 private flashLoanDataHash;

    constructor(Registry reg, string memory _name) {
        (balancer, comptroller, nativeToken, intermediateToken) =
            abi.decode(reg.get(_name), (IFlashLoaner, IComptroller, WETH, ERC20));
    }

    function update() external {
        ICToken[] memory allMarkets = comptroller.getAllMarkets();
        for (uint256 i = 0; i < allMarkets.length; i++) {
            ICToken cToken = allMarkets[i];

            if (!_isListed(cToken)) continue;

            (bool isNative, ERC20 token) = _underlying(cToken);
            cTokens[ERC20(token)] = cToken;
            if (!isNative) ERC20(token).safeApprove(address(cToken), type(uint256).max);
            emit CTokenSet(ERC20(token), cToken);
        }
    }

    function _underlying(ICToken cToken) internal view returns (bool, ERC20) {
        try cToken.underlying() returns (address token) {
            return (false, ERC20(token));
        } catch {
            return (true, nativeToken);
        }
    }

    function _isNativeCToken(ICToken cToken) internal view returns (bool isNative) {
        (isNative,) = _underlying(cToken);
    }

    function setCToken(ERC20 asset, ICToken cToken) external {
        if (!_isListed(cToken)) revert InvalidMarket();

        cTokens[asset] = cToken;
        if (asset != nativeToken) asset.safeApprove(address(cToken), type(uint256).max);
        emit CTokenSet(asset, cToken);
    }

    /// @inheritdoc IERC7399
    function maxFlashLoan(address asset) public view returns (uint256) {
        // Optimistically assume that balancer has enough liquidity of the intermediate token
        // Each compound fork has a different oracle, so it'd be hard to get the exact amount that we can borrow
        return ERC20(asset).balanceOf(address(_cToken(ERC20(asset))));
    }

    /// @inheritdoc IERC7399
    function flashFee(address asset, uint256 amount) external view returns (uint256) {
        uint256 max = maxFlashLoan(asset);
        require(max > 0, "Unsupported currency");
        uint256 fee = amount.mulWadUp(balancer.getProtocolFeesCollector().getFlashLoanFeePercentage());
        // If Balancer ever charges a fee, we can't repay it with the flash loan, so this wrapper becomes useless
        return amount >= max || fee > 0 ? type(uint256).max : 0;
    }

    function _flashLoan(address asset, uint256 amount, bytes memory data) internal override {
        bytes memory metadata = abi.encode(asset, amount, data);
        flashLoanDataHash = keccak256(metadata);
        uint256 max = intermediateToken.balanceOf(address(balancer));
        balancer.flashLoan(this, address(intermediateToken).toArray(), max.toArray(), metadata);
    }

    /// @inheritdoc IFlashLoanRecipient
    function receiveFlashLoan(
        address[] memory,
        uint256[] memory amounts,
        uint256[] memory,
        bytes memory params
    )
        external
        override
    {
        if (msg.sender != address(balancer)) revert NotBalancer();
        if (keccak256(params) != flashLoanDataHash) revert HashMismatch();
        delete flashLoanDataHash;

        (ERC20 asset, uint256 amount, bytes memory data) = abi.decode(params, (ERC20, uint256, bytes));

        uint256 intermediateAmount = amounts[0];
        ICToken cToken = _cToken(asset);
        ICToken intermediateCToken = _cToken(intermediateToken);

        _lend(intermediateCToken, intermediateAmount);
        _borrow(cToken, amount);

        _bridgeToCallback(address(asset), amount, 0, data);

        _repay(cToken, amount);
        _withdraw(intermediateCToken, intermediateAmount);

        intermediateToken.safeTransfer(address(balancer), intermediateAmount);
    }

    function _lend(ICToken cToken, uint256 amount) internal {
        if (_isNativeCToken(cToken)) {
            nativeToken.withdraw(amount);
            cToken.mint{ value: amount }();
        } else {
            _checkInteraction(cToken.mint(amount));
        }

        _checkInteraction(comptroller.enterMarkets(address(cToken).toArray())[0]);
    }

    function _withdraw(ICToken cToken, uint256 amount) internal {
        _checkInteraction(cToken.redeemUnderlying(amount));
        if (address(this).balance > 0) nativeToken.deposit{ value: amount }();
    }

    function _borrow(ICToken cToken, uint256 amount) internal {
        _checkInteraction(cToken.borrow(amount));
        if (address(this).balance > 0) nativeToken.deposit{ value: amount }();
    }

    function _repay(ICToken cToken, uint256 amount) internal {
        if (_isNativeCToken(cToken)) {
            nativeToken.withdraw(amount);
            cToken.repayBorrow{ value: amount }();
        } else {
            _checkInteraction(cToken.repayBorrow(amount));
        }
    }

    receive() external payable { }

    function _checkInteraction(Error _error) internal pure {
        if (_error != Error.NO_ERROR) revert FailedToRedeem(_error);
    }

    function _cToken(ERC20 asset) internal view returns (ICToken cToken) {
        cToken = cTokens[asset];
        if (cToken == ICToken(address(0))) revert CTokenNotFound(asset);
    }

    function _isListed(ICToken cToken) internal returns (bool) {
        (bool success, bytes memory data) =
            address(comptroller).call(abi.encodeWithSelector(IComptroller.markets.selector, cToken));

        return success && data.length >= 32 && isFirst32BytesTrue(data);
    }

    function isFirst32BytesTrue(bytes memory data) public pure returns (bool) {
        uint256 value;
        assembly {
            value := mload(add(data, 32))
        }
        return value != 0;
    }
}
