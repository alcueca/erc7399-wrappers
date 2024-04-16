// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { StdCheats } from "forge-std/StdCheats.sol";

import { IERC20Metadata as IERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IGnosisSafe } from "src/gnosissafe/interfaces/IGnosisSafe.sol";
import { MockBorrower } from "./MockBorrower.sol";
import { GnosisSafeWrapper } from "src/gnosissafe/GnosisSafeWrapper.sol";

/// @dev If this is your first time with Forge, read this tutorial in the Foundry Book:
/// https://book.getfoundry.sh/forge/writing-tests
contract GnosisSafeWrapperTest is Test {
    using SafeERC20 for IERC20;

    GnosisSafeWrapper internal wrapper;
    MockBorrower internal borrower;
    address internal USDT;
    address internal USDC;
    IGnosisSafe internal safe;

    /// @dev A function invoked before each test case is run.
    function setUp() public virtual {
        // Revert if there is no API key.
        string memory alchemyApiKey = vm.envOr("API_KEY_ALCHEMY", string(""));
        if (bytes(alchemyApiKey).length == 0) {
            revert("API_KEY_ALCHEMY variable missing");
        }

        vm.createSelectFork({ urlOrAlias: "gnosis", blockNumber: 33_471_377 });
        safe = IGnosisSafe(0x0faAe596Ce5d762BcD78b4415992726492570B54);
        USDT = 0x4ECaBa5870353805a9F068101A40E0f32ed605C6;
        USDC = 0xDDAfbb505ad214D7b80b1f830fcCc89B60fb7A83;

        wrapper = new GnosisSafeWrapper(address(this), safe);
        borrower = new MockBorrower(wrapper);

        deal(USDT, address(safe), 100e18);
        deal(USDT, address(borrower), 1e18);

        vm.prank(address(safe));
        safe.enableModule(address(wrapper));

        wrapper.setLendingData(USDT, 10, true);

    }

    /// @dev Basic test. Run it with `forge test -vvv` to see the console log.
    function test_flashFee() external {
        console2.log("test_flashFee");
        assertEq(wrapper.flashFee(USDT, 1e18), 1e15, "Flash fee not right");
    }

    function test_maxFlashLoan() external {
        console2.log("test_maxFlashLoan");
        assertEq(wrapper.maxFlashLoan(USDT), 100e18, "Max flash loan not right");
    }

    function test_maxFlashLoan_unsupportedAsset() external {
        console2.log("test_maxFlashLoan");
        assertEq(wrapper.maxFlashLoan(USDC), 0, "Max flash loan not right");
    }

    function test_flashFee_unsupportedAsset() external {
        console2.log("test_flashFee");
        vm.expectRevert(abi.encodeWithSelector(GnosisSafeWrapper.UnsupportedAsset.selector, USDC));
        wrapper.flashFee(USDC, 1e18);
    }

    function test_flashFee_insufficientLiquidity() external {
        console2.log("test_flashFee");
        assertEq(wrapper.flashFee(USDT, 20_000e18), type(uint256).max, "Flash fee not right");
    }

    function test_flashLoanDebug() external {
        console2.log("test_flashLoan");
        uint256 loan = 10e18;
        uint256 fee = wrapper.flashFee(USDT, loan);
        IERC20(USDT).safeTransfer(address(borrower), fee);
        bytes memory result = borrower.flashBorrow(USDT, loan);

        // Test the return values passed through the wrapper
        (bytes32 callbackReturn) = abi.decode(result, (bytes32));
        assertEq(uint256(callbackReturn), uint256(borrower.ERC3156PP_CALLBACK_SUCCESS()), "Callback failed");

        // Test the borrower state during the callback
        assertEq(borrower.flashInitiator(), address(borrower));
        assertEq(address(borrower.flashAsset()), address(USDT));
        assertEq(borrower.flashAmount(), loan);
        assertEq(borrower.flashBalance(), loan + fee); // The amount we transferred to pay for fees, plus the amount we
        // borrowed
        assertEq(borrower.flashFee(), fee);
    }
}
