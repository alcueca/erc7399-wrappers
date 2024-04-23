//SPDX-License-Identifier: MIT
pragma solidity >= 0.8.19;

import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";

import { GnosisSafeWrapper } from "./GnosisSafeWrapper.sol";

contract GnosisSafeWrapperFactory {
    event LenderCreated(address indexed safe, GnosisSafeWrapper _lender);
    event LendingDataSet(address indexed safe, address indexed asset, uint248 fee, bool enabled);

    address public constant ALL_ASSETS = address(0);

    GnosisSafeWrapper public immutable template;

    constructor() {
        template = new GnosisSafeWrapper();
    }

    /// @dev Returns true if `_lender` is a contract.
    /// @param _lender The address being checked.
    // This method relies on extcodesize, which returns 0 for contracts in
    // construction, since the code is only stored at the end of the
    // constructor execution.
    function _deployed(GnosisSafeWrapper _lender) internal view returns (bool) {
        return address(_lender).code.length > 0;
    }

    /// @dev Deploy a new Gnosis Safe wrapper for a Gnosis Safe.
    /// The factory will become the owner of the wrapper, and the safe will be able to govern the wrapper through the
    /// factory.
    /// There can ever be only one wrapper per safe
    /// @param safe Address of the Gnosis Safe.
    function _deploy(address safe) internal returns (GnosisSafeWrapper _lender) {
        _lender = GnosisSafeWrapper(Clones.cloneDeterministic(address(template), bytes20(safe)));
        _lender.initialize(safe);
        emit LenderCreated(safe, _lender);
    }

    /// @dev Get the Gnosis Safe wrapper for a Gnosis Safe, deploying it if it doesn't exist.
    /// @param safe Address of the Gnosis Safe.
    function _getOrDeploy(address safe) internal returns (GnosisSafeWrapper _lender) {
        _lender = lender(safe);
        if (!_deployed(_lender)) _lender = _deploy(safe);
    }

    /// @dev Deploy a new Gnosis Safe wrapper for a Gnosis Safe.
    /// @param safe Address of the Gnosis Safe.
    function deploy(address safe) public returns (GnosisSafeWrapper _lender) {
        _lender = _deploy(safe);
    }

    /// @dev Get the Gnosis Safe wrapper for a Gnosis Safe.
    /// @param safe Address of the Gnosis Safe.
    function lender(address safe) public view returns (GnosisSafeWrapper _lender) {
        _lender = GnosisSafeWrapper(Clones.predictDeterministicAddress(address(template), bytes20(safe)));
    }

    /// @dev Get the Gnosis Safe wrapper for the sender.
    function lender() public view returns (GnosisSafeWrapper _lender) {
        _lender = lender(msg.sender);
    }

    /// @dev Get the lending data for a Gnosis Safe and asset.
    /// @param safe Address of the Gnosis Safe.
    /// @param asset Address of the asset.
    function lending(address safe, address asset) public view returns (uint248 fee, bool enabled) {
        return lender(safe).lending(asset);
    }

    /// @dev Get the lending data for an asset for the sender.
    /// @param asset Address of the asset.
    function lending(address asset) public view returns (uint248 fee, bool enabled) {
        return lending(msg.sender, asset);
    }

    /// @dev Set lending data for an asset.
    /// @param asset Address of the asset.
    /// @param fee Fee for the flash loan (FP 1e-4)
    function lend(address asset, uint248 fee) public {
        GnosisSafeWrapper _lender = _getOrDeploy(msg.sender);
        _lender.lend(asset, fee, true);
        emit LendingDataSet(msg.sender, asset, fee, true);
    }

    /// @dev Disable lending for an asset.
    /// @param asset Address of the asset.
    function disableLend(address asset) public {
        GnosisSafeWrapper _lender = _getOrDeploy(msg.sender);
        (uint248 fee,) = _lender.lending(asset);
        _lender.lend(asset, fee, false);
        emit LendingDataSet(msg.sender, asset, fee, false);
    }

    /// @dev Set a lending data override for all assets.
    /// @param fee Fee for the flash loan (FP 1e-4)
    function lendAll(uint248 fee) public {
        GnosisSafeWrapper _lender = _getOrDeploy(msg.sender);
        _lender.lendAll(fee, true);
        emit LendingDataSet(msg.sender, ALL_ASSETS, fee, true);
    }

    /// @dev Disable the lending override for all assets.
    /// @notice If you have individual lending data set for assets, this will not affect them.
    function disableLendAll() public {
        GnosisSafeWrapper _lender = _getOrDeploy(msg.sender);
        (uint248 fee,) = _lender.lending(ALL_ASSETS);
        _lender.lendAll(fee, false);
        emit LendingDataSet(msg.sender, ALL_ASSETS, fee, false);
    }
}
