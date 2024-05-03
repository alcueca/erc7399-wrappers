// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";

import { IERC20Metadata as IERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { Arrays } from "src/utils/Arrays.sol";

import { IMorpho } from "../src/morpho/interfaces/IMorpho.sol";
import { MockBorrower } from "./MockBorrower.sol";
import { MorphoPendleWrapper, IPendleRouterV3 } from "../src/pendle/MorphoPendleWrapper.sol";

/// @dev If this is your first time with Forge, read this tutorial in the Foundry Book:
/// https://book.getfoundry.sh/forge/writing-tests
contract MorphoPendleWrapperTest is Test {
    using Arrays for uint256;
    using Arrays for address;
    using SafeERC20 for IERC20;

    MorphoPendleWrapper internal wrapper;
    MockBorrower internal borrower;
    address internal token;
    IMorpho internal morpho;
    IPendleRouterV3 internal pendleRouter;

    uint256 internal dust = 1e10;

    /// @dev A function invoked before each test case is run.
    function setUp() public virtual {
        // Revert if there is no API key.
        string memory alchemyApiKey = vm.envOr("API_KEY_ALCHEMY", string(""));
        if (bytes(alchemyApiKey).length == 0) {
            revert("API_KEY_ALCHEMY variable missing");
        }

        vm.createSelectFork({ urlOrAlias: "mainnet", blockNumber: 19_788_676 });
        morpho = IMorpho(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);
        pendleRouter = IPendleRouterV3(0x00000000005BBB0EF59571E58418F9a4357b68A0);
        token = 0xc69Ad9baB1dEE23F4605a82b3354F8E40d1E5966; // PT-weETH-27JUN2024

        wrapper = new MorphoPendleWrapper(morpho, pendleRouter);
        borrower = new MockBorrower(wrapper);
    }

    /// @dev Basic test. Run it with `forge test -vvv` to see the console log.
    function test_flashFee() external {
        console2.log("test_flashFee");
        assertEq(wrapper.flashFee(token, 1e18), 0, "Fee not zero");
    }

    function test_maxFlashLoan() external {
        console2.log("test_maxFlashLoan");
        assertEqDecimal(wrapper.maxFlashLoan(token), 6451.923761191633930312e18, 18, "Max flash loan not right");
    }

    function test_maxFlashLoan_unsupportedAsset() external {
        console2.log("test_maxFlashLoan");
        vm.expectRevert();
        assertEq(wrapper.maxFlashLoan(address(1)), 0, "Max flash loan not right");
    }

    function test_flashFee_insufficientLiquidity() external {
        console2.log("test_flashFee");
        assertEq(wrapper.flashFee(token, 20_000e18), type(uint256).max, "Fee not zero");
    }

    function test_flashLoan() external {
        console2.log("test_flashLoan");
        uint256 loan = 10e18;
        uint256 fee = wrapper.flashFee(token, loan);
        IERC20(token).safeTransfer(address(borrower), fee);
        bytes memory result = borrower.flashBorrow(token, loan);

        // Test the return values passed through the wrapper
        (bytes32 callbackReturn) = abi.decode(result, (bytes32));
        assertEq(uint256(callbackReturn), uint256(borrower.ERC3156PP_CALLBACK_SUCCESS()), "Callback failed");

        // Test the borrower state during the callback
        assertEq(borrower.flashInitiator(), address(borrower));
        assertEq(address(borrower.flashAsset()), address(token));
        assertEq(borrower.flashAmount(), loan);
        assertEq(borrower.flashBalance(), loan + fee); // The amount we transferred to pay for fees, plus the amount we
        // borrowed
        assertEq(borrower.flashFee(), fee);
    }

    function test_onMorphoFlashLoan_permissions() public {
        vm.expectRevert(MorphoPendleWrapper.NotMorpho.selector);
        wrapper.onMorphoFlashLoan({ amount: 0, params: "" });
    }

    function test_measureFlashLoanGas() public {
        console2.log("test_measureFlashLoanGas");
        uint256 loan = 10e18;
        uint256 fee = wrapper.flashFee(token, loan);
        IERC20(token).safeTransfer(address(borrower), fee);
        borrower.flashBorrowMeasureGas(token, loan, "MorphoPendle");
    }
}
