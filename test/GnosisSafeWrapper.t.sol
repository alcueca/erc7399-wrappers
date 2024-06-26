// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { StdCheats } from "forge-std/StdCheats.sol";

import { IERC20Metadata as IERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

import { IGnosisSafe } from "src/gnosissafe/interfaces/IGnosisSafe.sol";
import { MockBorrower } from "./MockBorrower.sol";
import { GnosisSafeWrapperFactory } from "src/gnosissafe/GnosisSafeWrapperFactory.sol";
import { GnosisSafeWrapper } from "src/gnosissafe/GnosisSafeWrapper.sol";

/// @dev If this is your first time with Forge, read this tutorial in the Foundry Book:
/// https://book.getfoundry.sh/forge/writing-tests
abstract contract GnosisSafeWrapperStateZero is Test {
    using SafeERC20 for IERC20;

    GnosisSafeWrapperFactory internal factory;
    GnosisSafeWrapper internal wrapper;
    MockBorrower internal borrower;
    address internal USDT;
    address internal USDC;
    IGnosisSafe internal safe;

    function _deployed(GnosisSafeWrapper _lender) internal view returns (bool) {
        return address(_lender).code.length > 0;
    }

    /// @dev A function invoked before each test case is run.
    function setUp() public virtual {
        // Revert if there is no API key.
        string memory alchemyApiKey = vm.envOr("API_KEY_ALCHEMY", string(""));
        if (bytes(alchemyApiKey).length == 0) {
            revert("API_KEY_ALCHEMY variable missing");
        }

        vm.createSelectFork({ urlOrAlias: "mainnet", blockNumber: 19_674_449 });
        safe = IGnosisSafe(0xfA6DaAF31F8E2498b5D4C43E59c6eDd345D951F5);
        USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
        USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

        factory = new GnosisSafeWrapperFactory();
        deal(USDT, address(safe), 100e18);
    }
}

contract GnosisSafeWrapperStateZeroTest is GnosisSafeWrapperStateZero {
    function test_deploy() external {
        console2.log("test_deploy");
        wrapper = factory.deploy(address(safe));
        assertEq(address(wrapper.safe()), address(safe));
    }

    function test_lender() external {
        console2.log("test_lender");
        wrapper = factory.deploy(address(safe));
        assertEq(address(factory.lender(address(safe))), address(wrapper));
    }

    function test_lend() external {
        console2.log("test_lend");
        vm.prank(address(safe));
        factory.lend(USDT, 10);
        wrapper = factory.lender(address(safe));
        (uint256 fee, bool enabled) = wrapper.lending(USDT);
        assertEq(fee, 10);
        assertEq(enabled, true);
    }

    function test_lendAll() external {
        console2.log("test_lendAll");
        vm.prank(address(safe));
        factory.lendAll(10);
        wrapper = factory.lender(address(safe));
        (uint256 fee, bool enabled) = wrapper.lending(wrapper.ALL_ASSETS());
        assertEq(fee, 10);
        assertEq(enabled, true);
    }

    function test_lenderNoParams() external {
        console2.log("test_lenderNoParams");
        vm.startPrank(address(safe));
        wrapper = factory.deploy(address(safe));
        assertEq(address(factory.lender()), address(wrapper));
        vm.stopPrank();
    }
}

abstract contract GnosisSafeWrapperWithWrapper is GnosisSafeWrapperStateZero {
    function setUp() public virtual override {
        super.setUp();

        vm.startPrank(address(safe));
        wrapper = factory.lender();
        safe.enableModule(address(wrapper));
        factory.lend(USDT, 10);
        vm.stopPrank();

        borrower = new MockBorrower(wrapper);
    }
}

contract GnosisSafeWrapperWithWrapperTest is GnosisSafeWrapperWithWrapper {
    function test_lend_unauthorized() external {
        console2.log("test_lend_unauthorized");
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), wrapper.DEFAULT_ADMIN_ROLE()
            )
        );
        wrapper.lend(USDT, 10, true);
    }

    function test_flashFee() external {
        console2.log("test_flashFee");
        assertEq(wrapper.flashFee(USDT, 1e18), 1e15, "Flash fee not right");
    }

    function test_lend_changeFee() external {
        console2.log("test_lend_changeFee");
        vm.prank(address(safe));
        factory.lend(USDT, 1);
        assertEq(wrapper.flashFee(USDT, 1e18), 1e14, "Flash fee not right");
    }

    function test_lendAll_changeFee() external {
        console2.log("test_lendAll_changeFee");
        vm.prank(address(safe));
        factory.lendAll(1);
        assertEq(wrapper.flashFee(USDT, 1e18), 1e14, "Flash fee not right");
        deal(USDC, address(safe), 100e18);
        assertEq(wrapper.flashFee(USDC, 1e18), 1e14, "Flash fee not right");
    }

    function test_lendAll_disable() external {
        console2.log("test_lendAll_changeFee");
        vm.startPrank(address(safe));
        factory.lendAll(1);
        factory.disableLendAll();
        vm.stopPrank();
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

    function test_flashLoan() external {
        console2.log("test_flashLoan");
        uint256 loan = 10e18;
        uint256 fee = wrapper.flashFee(USDT, loan);
        deal(USDT, address(borrower), fee);

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

    function test_lend_disable() external {
        console2.log("test_lend_disable");
        vm.prank(address(safe));
        factory.disableLend(USDT);
        vm.expectRevert(abi.encodeWithSelector(GnosisSafeWrapper.UnsupportedAsset.selector, USDT));
        borrower.flashBorrow(USDT, 1);
    }

    function test_measureFlashLoanGas() public {
        console2.log("test_measureFlashLoanGas");
        address token = USDT;
        uint256 loan = 10e18;
        uint256 fee = wrapper.flashFee(token, loan);
        deal(address(token), address(borrower), fee);
        borrower.flashBorrowMeasureGas(token, loan, "GnosisSafe");
    }
}
