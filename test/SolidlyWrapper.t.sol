// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { StdCheats } from "forge-std/StdCheats.sol";

import { IERC20Metadata as IERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Registry } from "src/Registry.sol";

import { MockBorrower } from "./MockBorrower.sol";
import { SolidlyWrapper } from "../src/solidly/SolidlyWrapper.sol";
import { IPoolFactory } from "../src/solidly/interfaces/IPoolFactory.sol";
import { Arrays } from "src/utils/Arrays.sol";

/// @dev If this is your first time with Forge, read this tutorial in the Foundry Book:
/// https://book.getfoundry.sh/forge/writing-tests
contract SolidlyWrapperTest is Test {
    using Arrays for *;

    SolidlyWrapper internal wrapper;
    MockBorrower internal borrower;
    address internal usdc;
    address internal reth;
    address internal weth;
    address internal cbeth;
    IPoolFactory internal factory;

    /// @dev A function invoked before each test case is run.
    function setUp() public virtual {
        vm.createSelectFork({ urlOrAlias: "base", blockNumber: 12_118_407 });
        factory = IPoolFactory(0x420DD381b31aEf6683db6B902084cB0FFECe40Da);
        usdc = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
        reth = 0xB6fe221Fe9EeF5aBa221c348bA20A1Bf5e73624c;
        weth = 0x4200000000000000000000000000000000000006;
        cbeth = 0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22;

        Registry registry = new Registry(address(this).toArray(), address(this).toArray());
        registry.set("AerodromeWrapper", abi.encode(factory, weth, usdc));
        wrapper = new SolidlyWrapper("AerodromeWrapper", registry);
        borrower = new MockBorrower(wrapper);
    }

    /// @dev Basic test. Run it with `forge test -vvv` to see the console log.
    function test_flashFee() external {
        console2.log("test_flashFee");
        assertEqDecimal(wrapper.flashFee(usdc, 100e6), 0.050026e6, 6, "Fee not exact USDC");
        assertEqDecimal(wrapper.flashFee(reth, 10e18), 0.03009027081243732e18, 18, "Fee not exact RETH");
        assertEqDecimal(wrapper.flashFee(weth, 0.1e18), 0.000050025012506254e18, 18, "Fee not exact IWETH9 1");
        assertEqDecimal(wrapper.flashFee(weth, 10e18), 0.03009027081243732e18, 18, "Fee not exact IWETH9 2");
        assertEqDecimal(wrapper.flashFee(cbeth, 1e18), 0.000500250125062532e18, 18, "Fee not exact CBETH");
    }

    function test_maxFlashLoan() external {
        console2.log("test_maxFlashLoan");
        assertEqDecimal(wrapper.maxFlashLoan(usdc), 32_739_908.187835e6, 6, "Max flash loan not right");
        assertEqDecimal(wrapper.maxFlashLoan(reth), 229.017266311094211102e18, 18, "Max flash loan not right");
        assertEqDecimal(wrapper.maxFlashLoan(weth), 9253.315045893317165385e18, 18, "Max flash loan not right");
        assertEqDecimal(wrapper.maxFlashLoan(cbeth), 1902.400249022382199415e18, 18, "Max flash loan not right");
    }

    function test_flashLoan_USDC() external {
        test_flashLoan(usdc, 100e6);
    }

    function test_flashLoan_RETH() external {
        test_flashLoan(reth, 10e18);
    }

    function test_flashLoan_WETH() external {
        test_flashLoan(weth, 10 ether);
    }

    function test_flashLoan_CBETH() external {
        test_flashLoan(cbeth, 1e18);
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

    function test_SolidlyFlashCallback_permissions() public {
        vm.expectRevert(SolidlyWrapper.Unauthorized.selector);
        vm.prank(0xcDAC0d6c6C59727a65F871236188350531885C43);
        wrapper.hook({ sender: address(this), amount0: 0, amount1: 0, params: abi.encode(weth, usdc, 0, false, "") });

        vm.expectRevert(SolidlyWrapper.UnknownPool.selector);
        wrapper.hook({ sender: address(wrapper), amount0: 0, amount1: 0, params: abi.encode(weth, usdc, 0, false, "") });
    }

    function test_measureFlashLoanGas() public {
        console2.log("test_measureFlashLoanGas");
        uint256 loan = 1e18;
        address token = weth;
        uint256 fee = wrapper.flashFee(token, loan);
        deal(address(token), address(borrower), fee);
        borrower.flashBorrowMeasureGas(token, loan, "Solidly");
    }
}
