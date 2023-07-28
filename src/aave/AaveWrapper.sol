// SPDX-License-Identifier: GPL-3.0-or-later
// Thanks to ultrasecr.eth
pragma solidity ^0.8.0;

// contract AaveFlashLoanProvider is BaseFlashLoanProvider, FlashLoanReceiverBase {
//     using Math for *;
//     using SafeERC20 for IERC20;
//     using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
//     using TransferLib for *;
// 
//     FlashLoanProvider public constant override id = FlashLoanProvider.Aave;
// 
//     AaveMoneyMarket public immutable moneyMarket;
// 
//     constructor(AaveMoneyMarket _moneyMarket) FlashLoanReceiverBase(_moneyMarket.provider()) {
//         moneyMarket = _moneyMarket;
//     }
// 
//     function calculateFlashLoanFeeAmount(IERC20Metadata asset, uint256 amount)
//         external
//         view
//         returns (uint256 feeAmount)
//     {
//         DataTypes.ReserveData memory reserve = POOL.getReserveData(address(asset));
//         DataTypes.ReserveConfigurationMap memory configuration = reserve.configuration;
// 
//         if (
//             !configuration.getPaused() && configuration.getActive() && configuration.getFlashLoanEnabled()
//                 && amount < asset.balanceOf(reserve.aTokenAddress)
//         ) feeAmount = amount.mulDiv(fee(), 1e18, Math.Rounding.Up);
//         else feeAmount = type(uint256).max;
//     }
// 
//     function fee() public view override returns (uint256) {
//         return POOL.FLASHLOAN_PREMIUM_TOTAL() * 0.0001e18;
//     }
// 
//     function flashLoan(
//         IERC20 asset,
//         uint256 amount,
//         address onBehalfOf,
//         bytes calldata params,
//         bool flashBorrow,
//         function(IERC20, uint256, bytes memory, address) external returns (bytes memory) callback
//     ) external override returns (bytes memory result) {
//         tmpResult = "";
//         MetaParams memory metaParams = MetaParams({params: params, flashBorrow: flashBorrow, callback: callback});
// 
//         if (flashBorrow) {
//             moneyMarket.delegateIfNecessary(asset, onBehalfOf, address(this));
//             // console.log("AAVE: flashBorrow %s", amount);
//         }
// 
//         POOL.flashLoan({
//             receiverAddress: address(this),
//             assets: toArray(address(asset)),
//             amounts: toArray(amount),
//             interestRateModes: toArray(flashBorrow ? 2 : 0),
//             onBehalfOf: flashBorrow ? onBehalfOf : address(this),
//             params: abi.encode(metaParams),
//             referralCode: 0
//         });
// 
//         result = tmpResult;
//     }
// 
//     function executeOperation(
//         address[] calldata assets,
//         uint256[] calldata amounts,
//         uint256[] calldata fees,
//         address initiator,
//         bytes calldata params
//     ) external override returns (bool) {
//         require(msg.sender == address(POOL), "not pool");
//         require(initiator == address(this), "AaveFlashLoanProvider: not initiator");
// 
//         MetaParams memory metaParams = abi.decode(params, (MetaParams));
// 
//         if (!metaParams.flashBorrow) IERC20(assets[0]).approveIfNecessary(address(POOL));
// 
//         IERC20(assets[0]).safeTransfer(metaParams.callback.address, amounts[0]);
// 
//         bytes memory result = metaParams.callback(
//             IERC20(assets[0]),
//             amounts[0] + (metaParams.flashBorrow ? 0 : fees[0]),
//             metaParams.params,
//             metaParams.flashBorrow ? address(0) : address(this)
//         );
// 
//         if (result.length > 0) tmpResult = result;
// 
//         return true;
//     }
// }