// SPDX-License-Identifier: GPL-3.0-or-later
// Thanks to ultrasecr.eth
pragma solidity ^0.8.0;

import { IERC3156PPFlashLender } from "lib/erc3156pp/src/interfaces/IERC3156PPFlashLender.sol";
import { IERC20 } from "lib/erc3156pp/src/interfaces/IERC20.sol";

import { TransferHelper } from "./utils/TransferHelper.sol";

abstract contract BaseWrapper is IERC3156PPFlashLender {
    using TransferHelper for IERC20;

    struct Data {
        address loanReceiver;
        address initiator;
        function(address, address, IERC20, uint256, uint256, bytes memory) external returns (bytes memory) callback;
        bytes initiatorData;
    }

    bytes internal _callbackResult;

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

    function _flashLoan(IERC20 asset, uint256 amount, bytes memory params) internal virtual;

    function _handleFlashLoan(IERC20 asset, uint256 amount, uint256 fee, bytes memory params) internal {
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

    function _transferAssets(IERC20 asset, uint256 amount, address loanReceiver) internal virtual {
        asset.safeTransfer(loanReceiver, amount);
    }

    function _approveRepayment(IERC20 asset, uint256 amount, uint256 fee) internal virtual {
        if (_repayTo() == address(this)) {
            asset.approve(msg.sender, amount + fee);
        }
    }

    function _repayTo() internal view virtual returns (address) {
        return address(this);
    }
}
