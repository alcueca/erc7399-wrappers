// SPDX-License-Identifier: MIT
// Thanks to ultrasecr.eth
pragma solidity ^0.8.19;

import { IFlashLoanRecipient } from "../balancer/interfaces/IFlashLoanRecipient.sol";
import { IFlashLoaner } from "../balancer/interfaces/IFlashLoaner.sol";
import { ISiloRepository } from "./interfaces/ISiloRepository.sol";
import { ISiloLens } from "./interfaces/ISiloLens.sol";
import { ISilo } from "./interfaces/ISilo.sol";

import { Arrays } from "../utils/Arrays.sol";

import { FixedPointMathLib } from "lib/solmate/src/utils/FixedPointMathLib.sol";
import { SafeTransferLib } from "lib/solmate/src/utils/SafeTransferLib.sol";

import { BaseWrapper, IERC7399, ERC20 } from "../BaseWrapper.sol";

/// @dev Silo Flash Lender that uses Balancer Pools as source of X liquidity,
/// then deposits X on Silo to borrow whatever's necessary.
contract SiloWrapper is BaseWrapper, IFlashLoanRecipient {
    using Arrays for uint256;
    using Arrays for address;
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;

    bool public constant COLLATERAL_ONLY = false;

    error NotBalancer();
    error HashMismatch();

    IFlashLoaner public immutable balancer;
    ISiloRepository public immutable repository;
    ISiloLens public immutable lens;
    ERC20 public immutable intermediateToken;

    bytes32 private flashLoanDataHash;

    constructor(ISiloLens _lens, IFlashLoaner _balancer, ERC20 _intermediateToken) {
        lens = _lens;
        repository = _lens.siloRepository();
        balancer = _balancer;
        intermediateToken = _intermediateToken;
    }

    /// @inheritdoc IERC7399
    function maxFlashLoan(address asset) public view returns (uint256) {
        // Optimistically assume that balancer has enough liquidity of the intermediate token
        // Each Silo fork has a different oracle, so it'd be hard to get the exact amount that we can borrow
        return lens.liquidity(repository.getSilo(ERC20(asset)), ERC20(asset));
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
        ISilo silo = _silo(asset);

        silo.deposit(intermediateToken, intermediateAmount, COLLATERAL_ONLY);
        silo.borrow(asset, amount);

        _bridgeToCallback(address(asset), amount, 0, data);

        silo.repay(asset, amount);
        silo.withdraw(intermediateToken, type(uint256).max, COLLATERAL_ONLY);

        intermediateToken.safeTransfer(address(balancer), intermediateAmount);
    }

    function _silo(ERC20 asset) internal returns (ISilo silo) {
        silo = repository.getSilo(asset);
        if (asset.allowance(address(this), address(silo)) == 0) {
            asset.safeApprove(address(silo), type(uint256).max);
        }
        if (intermediateToken.allowance(address(this), address(silo)) == 0) {
            intermediateToken.safeApprove(address(silo), type(uint256).max);
        }
    }
}
