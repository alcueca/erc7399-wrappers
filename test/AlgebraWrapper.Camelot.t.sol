// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";

import { IERC20Metadata as IERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Registry } from "src/Registry.sol";

import { MockBorrower } from "./MockBorrower.sol";
import { AlgebraWrapper } from "../src/algebra/AlgebraWrapper.sol";
import { IAlgebraFactory } from "../src/algebra/interfaces/IAlgebraFactory.sol";
import { Arrays } from "src/utils/Arrays.sol";

/// @dev If this is your first time with Forge, read this tutorial in the Foundry Book:
/// https://book.getfoundry.sh/forge/writing-tests
contract AlgebraWrapperCamelotTest is Test {
    using Arrays for *;

    AlgebraWrapper internal wrapper;
    MockBorrower internal borrower;
    address internal usdc;
    address internal ezeth;
    address internal weth;
    address internal wsteth;
    IAlgebraFactory internal factory;

    /// @dev A function invoked before each test case is run.
    function setUp() public virtual {
        vm.createSelectFork({ urlOrAlias: "arbitrum_one", blockNumber: 196_858_216 });
        factory = IAlgebraFactory(0x1a3c9B1d2F0529D97f2afC5136Cc23e58f1FD35B);
        usdc = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
        weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
        ezeth = 0x2416092f143378750bb29b79eD961ab195CcEea5;
        wsteth = 0x5979D7b546E38E414F7E9822514be443A4800529;

        Registry registry = new Registry(address(this).toArray(), address(this).toArray());
        registry.set("CamelotWrapper", abi.encode(factory, weth, usdc));
        wrapper = new AlgebraWrapper("CamelotWrapper", registry);
        borrower = new MockBorrower(wrapper);
    }

    /// @dev Basic test. Run it with `forge test -vvv` to see the console log.
    function test_flashFee() external {
        console2.log("test_flashFee");
        assertEqDecimal(wrapper.flashFee(usdc, 100e6), 0.01e6, 6, "Fee not exact USDC");
        assertEqDecimal(wrapper.flashFee(ezeth, 10e18), 0.001e18, 18, "Fee not exact EZETH");
        assertEqDecimal(wrapper.flashFee(weth, 10e18), 0.001e18, 18, "Fee not exact WETH");
        assertEqDecimal(wrapper.flashFee(wsteth, 10e18), 0.001e18, 18, "Fee not exact WSTETH");
    }

    function test_maxFlashLoan() external {
        console2.log("test_maxFlashLoan");
        assertEqDecimal(wrapper.maxFlashLoan(usdc), 1_664_763.738521e6, 6, "Max flash loan not right");
        assertEqDecimal(wrapper.maxFlashLoan(ezeth), 359.251536005526479693e18, 18, "Max flash loan not right");
        assertEqDecimal(wrapper.maxFlashLoan(weth), 1838.680169096461955273e18, 18, "Max flash loan not right");
        assertEqDecimal(wrapper.maxFlashLoan(wsteth), 70.036372160463629781e18, 18, "Max flash loan not right");
    }

    function test_flashLoan_USDC() external {
        test_flashLoan(usdc, 100e6);
    }

    function test_flashLoan_EZETH() external {
        test_flashLoan(ezeth, 10e18);
    }

    function test_flashLoan_WETH() external {
        test_flashLoan(weth, 10 ether);
    }

    function test_flashLoan_WSTETH() external {
        test_flashLoan(wsteth, 1e18);
    }

    function test_flashLoan(address token, uint256 loan) internal {
        console2.log(string.concat("test_flashLoan: ", IERC20(token).symbol()));
        uint256 fee = wrapper.flashFee(token, loan);
        deal(address(token), address(borrower), fee);
        bytes memory result = borrower.flashBorrow(token, loan);

        // Test the return values passed through the wrapper
        (bytes32 callbackReturn) = abi.decode(result, (bytes32));
        assertEq(uint256(callbackReturn), uint256(borrower.ERC3156PP_CALLBACK_SUCCESS()), "Callback failed");

        // Test the borrower state during the callback
        assertEq(borrower.flashInitiator(), address(borrower), "flashInitiator");
        assertEq(address(borrower.flashAsset()), address(token), "flashAsset");
        assertEq(borrower.flashAmount(), loan, "flashAmount");
        // The amount we transferred to pay for fees, plus the amount we borrowed
        assertEq(borrower.flashBalance(), loan + fee, "flashBalance");
        assertEq(borrower.flashFee(), fee, "flashFee");
    }

    function test_AlgebraFlashCallback_permissions() public {
        vm.expectRevert(AlgebraWrapper.Unauthorized.selector);
        wrapper.algebraFlashCallback({ fee0: 0, fee1: 0, params: abi.encode(weth, usdc, 0, "") });
    }

    function test_measureFlashLoanGasDebug() public {
        console2.log("test_measureFlashLoanGas");
        address token = wsteth;
        uint256 loan = 1e18;
        uint256 fee = wrapper.flashFee(token, loan);
        deal(address(token), address(borrower), fee);
        borrower.flashBorrowMeasureGas(token, loan, "AlgebraCamelot");
    }
}
