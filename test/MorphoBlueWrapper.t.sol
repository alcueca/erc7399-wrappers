// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { StdCheats } from "forge-std/StdCheats.sol";

import { IERC20Metadata as IERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IMorpho } from "src/morpho/interfaces/IMorpho.sol";
import { MockBorrower } from "./MockBorrower.sol";
import { MorphoBlueWrapper } from "src/morpho/MorphoBlueWrapper.sol";

/// @dev If this is your first time with Forge, read this tutorial in the Foundry Book:
/// https://book.getfoundry.sh/forge/writing-tests
contract MorphoBlueWrapperTest is Test {
    using SafeERC20 for IERC20;

    MorphoBlueWrapper internal wrapper;
    MockBorrower internal borrower;
    address internal wstETH;
    address internal arETH;
    IMorpho internal morpho;

    /// @dev A function invoked before each test case is run.
    function setUp() public virtual {
        // Revert if there is no API key.
        string memory alchemyApiKey = vm.envOr("API_KEY_ALCHEMY", string(""));
        if (bytes(alchemyApiKey).length == 0) {
            revert("API_KEY_ALCHEMY variable missing");
        }

        vm.createSelectFork({ urlOrAlias: "mainnet", blockNumber: 19_163_112 });
        morpho = IMorpho(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);
        wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
        arETH = 0xCc9EE9483f662091a1de4795249E24aC0aC2630f;

        wrapper = new MorphoBlueWrapper(morpho);
        borrower = new MockBorrower(wrapper);
    }

    /// @dev Basic test. Run it with `forge test -vvv` to see the console log.
    function test_flashFee() external {
        console2.log("test_flashFee");
        assertEq(wrapper.flashFee(wstETH, 1e18), 0, "Fee not zero");
    }

    function test_maxFlashLoan() external {
        console2.log("test_maxFlashLoan");
        assertEq(wrapper.maxFlashLoan(wstETH), 11_103.429478467444335345e18, "Max flash loan not right");
    }

    function test_maxFlashLoan_unsupportedAsset() external {
        console2.log("test_maxFlashLoan");
        assertEq(wrapper.maxFlashLoan(arETH), 0, "Max flash loan not right");
    }

    function test_flashFee_unsupportedAsset() external {
        console2.log("test_flashFee");
        vm.expectRevert(abi.encodeWithSelector(MorphoBlueWrapper.UnsupportedAsset.selector, arETH));
        wrapper.flashFee(arETH, 1e18);
    }

    function test_flashFee_insufficientLiquidity() external {
        console2.log("test_flashFee");
        assertEq(wrapper.flashFee(wstETH, 20_000e18), type(uint256).max, "Fee not zero");
    }

    function test_flashLoan() external {
        console2.log("test_flashLoan");
        uint256 loan = 100e18;
        uint256 fee = wrapper.flashFee(wstETH, loan);
        IERC20(wstETH).safeTransfer(address(borrower), fee);
        bytes memory result = borrower.flashBorrow(wstETH, loan);

        // Test the return values passed through the wrapper
        (bytes32 callbackReturn) = abi.decode(result, (bytes32));
        assertEq(uint256(callbackReturn), uint256(borrower.ERC3156PP_CALLBACK_SUCCESS()), "Callback failed");

        // Test the borrower state during the callback
        assertEq(borrower.flashInitiator(), address(borrower));
        assertEq(address(borrower.flashAsset()), address(wstETH));
        assertEq(borrower.flashAmount(), loan);
        assertEq(borrower.flashBalance(), loan + fee); // The amount we transferred to pay for fees, plus the amount we
        // borrowed
        assertEq(borrower.flashFee(), fee);
    }

    function test_onMorphoFlashLoan_permissions() public {
        vm.expectRevert(MorphoBlueWrapper.NotMorpho.selector);
        wrapper.onMorphoFlashLoan({ amount: 0, params: "" });
    }

    function test_measureFlashLoanGas() public {
        console2.log("test_measureFlashLoanGas");
        uint256 loan = 100e18;
        uint256 fee = wrapper.flashFee(wstETH, loan);
        IERC20(wstETH).safeTransfer(address(borrower), fee);
        borrower.flashBorrowMeasureGas(wstETH, loan, "MorphoBlue");
    }
}
