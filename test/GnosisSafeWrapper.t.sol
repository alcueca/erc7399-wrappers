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
        assertEq(address(factory.lenders(address(safe))), address(wrapper));
        assertEq(address(wrapper.safe()), address(safe));
    }

    function test_predictLenderAddressDebug() external {
        console2.log("test_predictLenderAddress");
        wrapper = factory.deploy(address(safe));
        assertEq(factory.predictLenderAddress(address(safe)), address(wrapper));
    }

    function test_lendDebug() external {
        console2.log("test_lend");
        vm.prank(address(safe));
        factory.lend(USDT, 10, true);
        wrapper = GnosisSafeWrapper(factory.predictLenderAddress(address(safe)));
        (uint256 fee, bool enabled) = wrapper.lending(USDT);
        assertEq(fee, 10);
        assertEq(enabled, true);
    }

    function test_lendAll() external {
        console2.log("test_lendAll");
        vm.prank(address(safe));
        factory.lendAll(10, true);
        wrapper = GnosisSafeWrapper(factory.predictLenderAddress(address(safe)));
        (uint256 fee, bool enabled) = wrapper.lending(wrapper.ALL_ASSETS());
        assertEq(fee, 10);
        assertEq(enabled, true);
    }

    function test_myLender() external {
        console2.log("test_myLender");
        vm.startPrank(address(safe));
        wrapper = factory.deploy(address(safe));
        assertEq(factory.myLender(), address(wrapper));
        vm.stopPrank();
    }
}

abstract contract GnosisSafeWrapperWithWrapper is GnosisSafeWrapperStateZero {
    function setUp() public override virtual {
        super.setUp();

        vm.startPrank(address(safe));
        wrapper = GnosisSafeWrapper(factory.myLender());
        safe.enableModule(address(wrapper));
        factory.lend(USDT, 10, true);
        vm.stopPrank();
        
        borrower = new MockBorrower(wrapper);
    }
}

contract GnosisSafeWrapperWithWrapperTest is GnosisSafeWrapperWithWrapper {
    function test_setLendingData_unauthorized() external {
        console2.log("test_setLendingData_unauthorized");
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

    function test_setLendingData_changeFee() external {
        console2.log("test_setLendingData_changeFee");
        vm.prank(address(safe));
        factory.lend(USDT, 1, true);
        assertEq(wrapper.flashFee(USDT, 1e18), 1e14, "Flash fee not right");
    }

    function test_setLendingDataAll_changeFee() external {
        console2.log("test_setLendingDataAll_changeFee");
        vm.prank(address(safe));
        factory.lendAll(1, true);
        assertEq(wrapper.flashFee(USDT, 1e18), 1e14, "Flash fee not right");
        deal(USDC, address(safe), 100e18);
        assertEq(wrapper.flashFee(USDC, 1e18), 1e14, "Flash fee not right");
    }

    function test_setLendingDataAll_disable() external {
        console2.log("test_setLendingDataAll_changeFee");
        vm.startPrank(address(safe));
        factory.lendAll(1, true);
        factory.lendAll(1, false);
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

    function test_setLendingData_disable() external {
        console2.log("test_setLendingData_disable");
        vm.prank(address(safe));
        factory.lend(USDT, 10, false);
        vm.expectRevert(abi.encodeWithSelector(GnosisSafeWrapper.UnsupportedAsset.selector, USDT));
        borrower.flashBorrow(USDT, 1);
    }
}
