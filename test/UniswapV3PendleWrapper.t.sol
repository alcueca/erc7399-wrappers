// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";

import { IERC20Metadata as IERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { Arrays } from "src/utils/Arrays.sol";

import { MockBorrower } from "./MockBorrower.sol";
import { IUniswapV3Factory } from "../src/uniswapV3/interfaces/IUniswapV3Factory.sol";
import { Arrays } from "src/utils/Arrays.sol";
import { UniswapV3PendleWrapper, IPendleRouterV3 } from "../src/pendle/UniswapV3PendleWrapper.sol";

/// @dev If this is your first time with Forge, read this tutorial in the Foundry Book:
/// https://book.getfoundry.sh/forge/writing-tests
contract UniswapV3PendleWrapperTest is Test {
    using Arrays for uint256;
    using Arrays for address;
    using SafeERC20 for IERC20;

    UniswapV3PendleWrapper internal wrapper;
    MockBorrower internal borrower;
    address internal token;
    IUniswapV3Factory internal factory;
    IPendleRouterV3 internal pendleRouter;
    address internal weth;
    address internal underlying;
    address internal owner = makeAddr("owner");

    uint256 internal dust = 1e10;

    /// @dev A function invoked before each test case is run.
    function setUp() public virtual {
        // Revert if there is no API key.
        string memory alchemyApiKey = vm.envOr("API_KEY_ALCHEMY", string(""));
        if (bytes(alchemyApiKey).length == 0) {
            revert("API_KEY_ALCHEMY variable missing");
        }

        vm.createSelectFork({ urlOrAlias: "arbitrum_one", blockNumber: 199_563_251 });
        factory = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
        pendleRouter = IPendleRouterV3(0x00000000005BBB0EF59571E58418F9a4357b68A0);
        weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
        token = 0x8EA5040d423410f1fdc363379Af88e1DB5eA1C34; // PT-ezETH-27JUN2024
        underlying = 0x2416092f143378750bb29b79eD961ab195CcEea5;

        wrapper = new UniswapV3PendleWrapper(owner, address(factory), weth, pendleRouter);
        borrower = new MockBorrower(wrapper);

        // Wrapper needs balance to cover fees
        deal(underlying, address(wrapper), 1e18);
        deal(address(token), address(this), 1e18); // For fees
    }

    function test_flashFee() external {
        console2.log("test_flashFee");
        assertEqDecimal(wrapper.flashFee(token, 1e18), 0.0001e18, 18, "Fee");
    }

    function test_maxFlashLoan_PTezETH() external {
        token = 0x8EA5040d423410f1fdc363379Af88e1DB5eA1C34; // PT-ezETH-27JUN2024
        underlying = 0x2416092f143378750bb29b79eD961ab195CcEea5;

        test_maxFlashLoan(103.703691885699322816e18);
    }

    function test_maxFlashLoan_PTeETH() external {
        token = 0x1c27Ad8a19Ba026ADaBD615F6Bc77158130cfBE4; // PT-eETH-27JUN2024
        underlying = 0x35751007a407ca6FEFfE80b3cB397736D2cf4dbe;

        test_maxFlashLoan(116.621531724330957646e18);
    }

    function test_maxFlashLoan_PTrsETH() external {
        token = 0xAFD22F824D51Fb7EeD4778d303d4388AC644b026; // PT-rsETH-27JUN2024
        underlying = 0x4186BFC76E2E237523CBC30FD220FE055156b41F;

        test_maxFlashLoan(8.816052000596960554e18);
    }

    function test_maxFlashLoan(uint256 expected) internal {
        console2.log("test_maxFlashLoan");

        deal(underlying, address(wrapper), 100e18);
        assertEqDecimal(wrapper.maxFlashLoan(token), expected, 18, "Max flash loan not right");

        deal(underlying, address(wrapper), 0.0001e18);
        assertLe(wrapper.maxFlashLoan(token), 1e18, "Max flash loan not right");
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

    function test_flashLoan_PTezETH() external {
        token = 0x8EA5040d423410f1fdc363379Af88e1DB5eA1C34; // PT-ezETH-27JUN2024
        underlying = 0x2416092f143378750bb29b79eD961ab195CcEea5;
        // Wrapper needs balance to cover fees
        deal(underlying, address(wrapper), 1e18);
        deal(address(token), address(this), 1e18); // For fees

        test_flashLoan(10e18);
    }

    function test_flashLoan_PTeETH() external {
        token = 0x1c27Ad8a19Ba026ADaBD615F6Bc77158130cfBE4; // PT-eETH-27JUN2024
        underlying = 0x35751007a407ca6FEFfE80b3cB397736D2cf4dbe;
        // Wrapper needs balance to cover fees
        deal(underlying, address(wrapper), 1e18);
        deal(address(token), address(this), 1e18); // For fees

        test_flashLoan(10e18);
    }

    function test_flashLoan_PTrsETH() external {
        token = 0xAFD22F824D51Fb7EeD4778d303d4388AC644b026; // PT-rsETH-27JUN2024
        underlying = 0x4186BFC76E2E237523CBC30FD220FE055156b41F;
        // Wrapper needs balance to cover fees
        deal(underlying, address(wrapper), 1e18);
        deal(address(token), address(this), 1e18); // For fees

        test_flashLoan(1e18);
    }

    function test_flashLoan(uint256 loan) internal {
        console2.log("test_flashLoan");
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
        assertEqDecimal(IERC20(token).balanceOf(address(wrapper)), fee, 18, "Fee not collected by wrapper");
        address treasury = makeAddr("treasury");
        vm.prank(owner);
        wrapper.retrieve(IERC20(token), treasury, fee);
        assertEqDecimal(IERC20(token).balanceOf(treasury), fee, 18, "Fee not transferred");
        assertEqDecimal(IERC20(token).balanceOf(address(wrapper)), 0, 18, "Fee still in wrapper");
    }

    function testRetrievePermissions() public {
        vm.expectRevert();
        wrapper.retrieve(IERC20(token), makeAddr("treasury"), 1e18);
    }

    function test_uniswapV3FlashCallback_permissions() public {
        vm.expectRevert(UniswapV3PendleWrapper.UnknownPool.selector);
        wrapper.uniswapV3FlashCallback({
            fee0: 0,
            fee1: 0,
            params: abi.encode(address(token), address(underlying), uint24(0.0005e6), uint256(0), "")
        });
    }

    function test_measureFlashLoanGas() public {
        console2.log("test_measureFlashLoanGas");
        uint256 loan = 1e18;
        uint256 fee = wrapper.flashFee(token, loan);
        IERC20(token).safeTransfer(address(borrower), fee);
        borrower.flashBorrowMeasureGas(token, loan, "UniswapV3Pendle");
    }
}
