// SPDX-License-Identifier: MIT
// Thanks to ultrasecr.eth
pragma solidity ^0.8.0;

import { IERC3156PPFlashLender } from "lib/erc3156pp/src/interfaces/IERC3156PPFlashLender.sol";
import { IERC20 } from "lib/erc3156pp/src/interfaces/IERC20.sol";

import { TransferHelper } from "./utils/TransferHelper.sol";

abstract contract BaseWrapper is IERC3156PPFlashLender {
    using TransferHelper for IERC20;

    event GasUsed(uint256 gasUsed);

    struct Data {
        address loanReceiver;
        address initiator;
        function(address, address, IERC20, uint256, uint256, bytes memory) external returns (bytes memory) callback;
        bytes initiatorData;
    }

    bytes internal _callbackResult;

    uint256 public expectedGas;

    /// @inheritdoc IERC3156PPFlashLender
    function flashLoan(
        address loanReceiver,
        IERC20 asset,
        uint256 amount,
        bytes calldata initiatorData,
        function(address, address, IERC20, uint256, uint256, bytes memory) external returns (bytes memory) callback
    )
        external
        returns (bytes memory result)
    {
        Data memory data = Data({
            loanReceiver: loanReceiver,
            initiator: msg.sender,
            callback: callback,
            initiatorData: initiatorData
        });

        _flashLoan(asset, amount, abi.encode(data));

        result = _callbackResult;
        // Avoid storage write if not needed
        if (result.length > 0) {
            delete _callbackResult;
        }
        return result;
    }

    /// @dev Call the flashloan function in the child contract
    function _flashLoan(IERC20 asset, uint256 amount, bytes memory params) internal virtual;

    /// @dev Handle the common parts of bridging the callback
    function bridgeToCallback(IERC20 asset, uint256 amount, uint256 fee, bytes memory params) internal {
        Data memory data = abi.decode(params, (Data));
        _transferAssets(asset, amount, data.loanReceiver);

        // call the callback and tell the callback receiver to repay the loan to this contract
        bytes memory result = data.callback(data.initiator, _repayTo(), IERC20(asset), amount, fee, data.initiatorData);

        _approveRepayment(asset, amount, fee);

        if (result.length > 0) {
            // if there's any result, it is kept in a storage variable to be retrieved later in this tx
            _callbackResult = result;
        }
    }

    /// @dev Transfer the assets to the loan receiver.
    /// Override it if the provider can send the funds directly
    function _transferAssets(IERC20 asset, uint256 amount, address loanReceiver) internal virtual {
        asset.safeTransfer(loanReceiver, amount);
    }

    /// @dev Approve the repayment of the loan to the provider if needed.
    /// Override it if the provider can receive the funds directly and you want to avoid the if condition
    function _approveRepayment(IERC20 asset, uint256 amount, uint256 fee) internal virtual {
        if (_repayTo() == address(this)) {
            asset.approve(msg.sender, amount + fee);
        }
    }

    /// @dev Where should the end client send the funds to repay the loan
    /// Override it if the provider can receive the funds directly
    function _repayTo() internal view virtual returns (address) {
        return address(this);
    }

    /// @dev Measure and record gas used in flash loans
    function setExpectedGas(IERC20 asset) external returns (uint256 gasUsed){
        uint256 gasLeftBefore = gasleft();
        this.flashLoan(address(this), asset, 10 ** asset.decimals(), "", this.gasCallback);

        gasUsed = gasLeftBefore - gasleft();
        expectedGas = gasUsed;
        emit GasUsed(gasUsed);
    }

    /// @dev Callback function used to measure gas used in flash loans
    function gasCallback(
        address,
        address repayTo,
        IERC20 asset,
        uint256 amount,
        uint256 fee,
        bytes memory
    )
        external
        returns (bytes memory)
    {
        if (repayTo != address(0)) _transferAssets(asset, amount + fee, repayTo);
        return "";
    }
}
