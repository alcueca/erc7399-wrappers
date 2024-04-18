//SPDX-License-Identifier: MIT
pragma solidity >= 0.8.19;

import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";

import { GnosisSafeWrapper } from "./GnosisSafeWrapper.sol";

contract GnosisSafeWrapperFactory {
    event LenderCreated(address safe, GnosisSafeWrapper lender);
    event LendingDataSet(address safe, address asset, uint248 fee, bool enabled);

    address public constant ALL_ASSETS = address(0);

    GnosisSafeWrapper public immutable template;

    mapping(address safe => GnosisSafeWrapper lender) public lenders;

    constructor() {
        template = new GnosisSafeWrapper();
    }

    function _deploy(address safe) internal returns (GnosisSafeWrapper lender) {
        lender = GnosisSafeWrapper(Clones.cloneDeterministic(address(template), bytes20(safe)));
        lender.initialize(safe);
        lenders[safe] = lender;
        emit LenderCreated(safe, lender);
    }

    function deploy(address safe) public returns (GnosisSafeWrapper lender) {
        lender = _deploy(safe);
    }

    function predictLenderAddress(address safe) public view returns (address lender) {
        lender = Clones.predictDeterministicAddress(address(template), bytes20(safe));
    }

    function myLender() public view returns (address lender) {
        lender = Clones.predictDeterministicAddress(address(template), bytes20(msg.sender));
    }

    function lending(address asset) public view returns (uint248 fee, bool enabled) {
        return lenders[msg.sender].lending(asset);
    }

    function lending(address safe, address asset) public view returns (uint248 fee, bool enabled) {
        return lenders[safe].lending(asset);
    }

    /// @dev Set lending data for an asset.
    /// @param asset Address of the asset.
    /// @param fee Fee for the flash loan (FP 1e-4)
    /// @param enabled Whether the asset is enabled for flash loans.
    function lend(address asset, uint248 fee, bool enabled) public {
        GnosisSafeWrapper lender = lenders[msg.sender];
        if (lender == GnosisSafeWrapper(address(0))) lender = _deploy(msg.sender);
        lender.lend(asset, fee, enabled);
        emit LendingDataSet(msg.sender, asset, fee, enabled);
    }

    /// @dev Set a lending data override for all assets.
    /// @param fee Fee for the flash loan (FP 1e-4)
    /// @param enabled Whether the lending data override is enabled for flash loans.
    function lendAll(uint248 fee, bool enabled) public {
        GnosisSafeWrapper lender = lenders[msg.sender];
        if (lender == GnosisSafeWrapper(address(0))) lender = _deploy(msg.sender);
        lender.lendAll(fee, enabled);
        emit LendingDataSet(msg.sender, address(0), fee, enabled);
    }
}
