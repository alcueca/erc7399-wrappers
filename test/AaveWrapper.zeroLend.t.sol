// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { StdCheats } from "forge-std/StdCheats.sol";

import { Registry } from "src/Registry.sol";

import { IERC20Metadata as IERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { MockBorrower } from "./MockBorrower.sol";
import { AaveWrapper } from "../src/aave/AaveWrapper.sol";
import { Arrays } from "src/utils/Arrays.sol";
import { IPoolAddressesProviderV3 } from "../src/aave/interfaces/IPoolAddressesProviderV3.sol";

/// @dev If this is your first time with Forge, read this tutorial in the Foundry Book:
/// https://book.getfoundry.sh/forge/writing-tests
contract AaveWrapperZerolendTest is Test {
    using Arrays for *;
    using SafeERC20 for IERC20;

    AaveWrapper internal wrapper;
    MockBorrower internal borrower;
    address internal weeth;
    IPoolAddressesProviderV3 internal provider;

    /// @dev A function invoked before each test case is run.
    function setUp() public virtual {
        // Revert if there is no API key.
        string memory alchemyApiKey = vm.envOr("API_KEY_ALCHEMY", string(""));
        if (bytes(alchemyApiKey).length == 0) {
            revert("API_KEY_ALCHEMY variable missing");
        }

        vm.createSelectFork({ urlOrAlias: "mainnet", blockNumber: 19_717_365 });
        provider = IPoolAddressesProviderV3(0xFD856E1a33225B86f70D686f9280435E3fF75FCF);
        weeth = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;

        Registry registry = new Registry(address(this).toArray(), address(this).toArray());
        registry.set(
            "ZerolendWrapper", abi.encode(provider.getPool(), address(provider), provider.getPoolDataProvider(), false)
        );

        wrapper = new AaveWrapper(registry, "Zerolend");
        borrower = new MockBorrower(wrapper);
        deal(address(weeth), address(this), 1e18); // For fees
    }

    /// @dev Basic test. Run it with `forge test -vvv` to see the console log.
    function test_flashFee() external {
        console2.log("test_flashFee");
        assertEq(wrapper.flashFee(weeth, 1e18), 5e14, "Fee not right");
    }

    function test_maxFlashLoan() external {
        console2.log("test_maxFlashLoan");
        assertEqDecimal(wrapper.maxFlashLoan(weeth), 264.036169146649164802e18, 18, "Max flash loan not right");
    }

    function test_flashLoan() external {
        console2.log("test_flashLoan");
        uint256 loan = 1e18;
        uint256 fee = wrapper.flashFee(weeth, loan);
        IERC20(weeth).safeTransfer(address(borrower), fee);
        bytes memory result = borrower.flashBorrow(weeth, loan);

        // Test the return values passed through the wrapper
        (bytes32 callbackReturn) = abi.decode(result, (bytes32));
        assertEq(uint256(callbackReturn), uint256(borrower.ERC3156PP_CALLBACK_SUCCESS()), "Callback failed");

        // Test the borrower state during the callback
        assertEq(borrower.flashInitiator(), address(borrower));
        assertEq(address(borrower.flashAsset()), address(weeth));
        assertEq(borrower.flashAmount(), loan);
        assertEq(borrower.flashBalance(), loan + fee); // The amount we transferred to pay for fees, plus the amount we
            // borrowed
        assertEq(borrower.flashFee(), fee);
    }

    function test_executeOperation_permissions() public {
        vm.expectRevert(AaveWrapper.NotPool.selector);
        wrapper.executeOperation({
            assets: address(weeth).toArray(),
            amounts: 1e18.toArray(),
            fees: 0.toArray(),
            initiator: address(wrapper),
            params: ""
        });

        vm.prank(provider.getPool());
        vm.expectRevert(AaveWrapper.NotInitiator.selector);
        wrapper.executeOperation({
            assets: address(weeth).toArray(),
            amounts: 1e18.toArray(),
            fees: 0.toArray(),
            initiator: address(0x666),
            params: ""
        });
    }

    function test_measureFlashLoanGas() public {
        console2.log("test_measureFlashLoanGas");
        uint256 loan = 1e18;
        uint256 fee = wrapper.flashFee(weeth, loan);
        IERC20(weeth).safeTransfer(address(borrower), fee);
        borrower.flashBorrowMeasureGas(weeth, loan, "Zerolend");
    }
}
