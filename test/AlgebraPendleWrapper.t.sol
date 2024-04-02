// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";

import { IERC20Metadata as IERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { Arrays } from "src/utils/Arrays.sol";

import { IAlgebraFactory } from "../src/algebra/interfaces/IAlgebraFactory.sol";
import { MockBorrower } from "./MockBorrower.sol";
import { AlgebraPendleWrapper, IPendleRouterV3 } from "../src/pendle/AlgebraPendleWrapper.sol";

/// @dev If this is your first time with Forge, read this tutorial in the Foundry Book:
/// https://book.getfoundry.sh/forge/writing-tests
contract AlgebraPendleWrapperTest is Test {
    using Arrays for uint256;
    using Arrays for address;
    using SafeERC20 for IERC20;

    AlgebraPendleWrapper internal wrapper;
    MockBorrower internal borrower;
    address internal token;
    IAlgebraFactory internal factory;
    IPendleRouterV3 internal pendleRouter;
    address internal usdc;
    address internal weth;
    address internal ezeth;
    address internal owner = makeAddr("owner");

    uint256 internal dust = 1e10;

    /// @dev A function invoked before each test case is run.
    function setUp() public virtual {
        // Revert if there is no API key.
        string memory alchemyApiKey = vm.envOr("API_KEY_ALCHEMY", string(""));
        if (bytes(alchemyApiKey).length == 0) {
            revert("API_KEY_ALCHEMY variable missing");
        }

        vm.createSelectFork({ urlOrAlias: "arbitrum_one", blockNumber: 196_782_299 });
        factory = IAlgebraFactory(0x1a3c9B1d2F0529D97f2afC5136Cc23e58f1FD35B);
        pendleRouter = IPendleRouterV3(0x00000000005BBB0EF59571E58418F9a4357b68A0);
        usdc = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
        weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
        token = 0x8EA5040d423410f1fdc363379Af88e1DB5eA1C34; // PT-ezETH-27JUN2024
        ezeth = 0x2416092f143378750bb29b79eD961ab195CcEea5;

        wrapper = new AlgebraPendleWrapper(owner, factory, weth, usdc, pendleRouter);
        borrower = new MockBorrower(wrapper);

        // Wrapper needs balance to cover fees
        deal(ezeth, address(wrapper), 1e18);

        deal(address(token), address(this), 1e18); // For fees
    }

    function test_flashFee() external {
        console2.log("test_flashFee");
        assertEqDecimal(wrapper.flashFee(token, 1e18), 0.0001e18, 18, "Fee");
    }

    function test_maxFlashLoan() external {
        console2.log("test_maxFlashLoan");

        deal(ezeth, address(wrapper), 100e18);
        assertEqDecimal(wrapper.maxFlashLoan(token), 385.724535031973029964e18, 18, "Max flash loan not right");

        deal(ezeth, address(wrapper), 0.01e18);
        assertEqDecimal(wrapper.maxFlashLoan(token), 100e18, 18, "Max flash loan not right");
    }

    function test_maxFlashLoan_unsupportedAsset() external {
        console2.log("test_maxFlashLoan");
        vm.expectRevert();
        assertEq(wrapper.maxFlashLoan(address(1)), 0, "Max flash loan not right");
    }

    function test_flashFee_unsupportedAsset() external {
        console2.log("test_flashFee");
        vm.expectRevert();
        wrapper.flashFee(address(1), 1e18);
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

        // Owner can retrieve the fees
        assertEqDecimal(IERC20(token).balanceOf(address(wrapper)), 0.001e18, 18, "Fee not collected by wrapper");
        address treasury = makeAddr("treasury");
        vm.prank(owner);
        wrapper.retrieve(IERC20(token), treasury, 0.001e18);
        assertEqDecimal(IERC20(token).balanceOf(treasury), 0.001e18, 18, "Fee not transferred");
        assertEqDecimal(IERC20(token).balanceOf(address(wrapper)), 0, 18, "Fee still in wrapper");
    }

    function testRetrievePermissions() public {
        vm.expectRevert();
        wrapper.retrieve(IERC20(token), makeAddr("treasury"), 1e18);
    }

    function test_AlgebraFlashCallback_permissions() public {
        vm.expectRevert(AlgebraPendleWrapper.Unauthorized.selector);
        wrapper.algebraFlashCallback({ fee0: 0, fee1: 0, params: abi.encode(ezeth, weth, usdc, 0, "") });
    }
}
