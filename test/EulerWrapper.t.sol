// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import { EulerWrapper, IERC20 } from "../src/euler/EulerWrapper.sol";
import { IEVault } from "../src/euler/interfaces/IEVault.sol";
import { IEVKFactoryPerspective } from "../src/euler/interfaces/IEVKFactoryPerspective.sol";
import { MockBorrower } from "./MockBorrower.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { CommonBase } from "forge-std/Base.sol";
import { StdChains } from "forge-std/StdChains.sol";
import { StdCheats, StdCheatsSafe } from "forge-std/StdCheats.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";

/// @dev If this is your first time with Forge, read this tutorial in the Foundry Book:
/// https://book.getfoundry.sh/forge/writing-tests
contract EulerWrapperTest is Test {
    using SafeERC20 for IERC20;

    IEVKFactoryPerspective public mockEvkFactory;
    EulerWrapper internal wrapper;
    MockBorrower internal borrower;
    address internal USDC;
    address internal arETH;
    address internal usdcVault1;
    address internal usdcVault2;

    /// @dev A function invoked before each test case is run.
    function setUp() public virtual {
        // Revert if there is no API key.
        string memory alchemyApiKey = vm.envOr("API_KEY_ALCHEMY", string(""));
        if (bytes(alchemyApiKey).length == 0) {
            revert("API_KEY_ALCHEMY variable missing");
        }

        vm.createSelectFork({ urlOrAlias: "base", blockNumber: 30_614_524 });
        mockEvkFactory = IEVKFactoryPerspective(address(vm.addr(1)));
        usdcVault1 = 0xC063C3b3625DF5F362F60f35B0bcd98e0fa650fb; // 69932415752 balance
        usdcVault2 = 0x0A1a3b5f2041F33522C4efc754a7D096f880eE16; // 1985258139987 balance
        USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
        arETH = 0xCc9EE9483f662091a1de4795249E24aC0aC2630f;

        address[] memory vaults = new address[](2);
        vaults[0] = usdcVault1;
        vaults[1] = usdcVault2;
        vm.mockCall(
            address(mockEvkFactory),
            abi.encodeWithSelector(IEVKFactoryPerspective.verifiedArray.selector),
            abi.encode(vaults)
        );
        vm.mockCall(
            address(mockEvkFactory),
            abi.encodeWithSelector(mockEvkFactory.isVerified.selector, usdcVault1),
            abi.encode(true)
        );
        vm.mockCall(
            address(mockEvkFactory),
            abi.encodeWithSelector(mockEvkFactory.isVerified.selector, usdcVault2),
            abi.encode(true)
        );

        wrapper = new EulerWrapper(mockEvkFactory);
        borrower = new MockBorrower(wrapper);
    }

    /// @dev Basic test. Run it with `forge test -vvv` to see the console log.
    function test_flashFee() external {
        console2.log("test_flashFee");
        assertEq(wrapper.flashFee(USDC, 10e6), 0, "Fee not zero");
    }

    function test_flashFee_unsupportedAsset() external {
        console2.log("test_flashFee");
        vm.expectRevert(abi.encodeWithSelector(EulerWrapper.UnsupportedAsset.selector, arETH));
        wrapper.flashFee(arETH, 1e18);
    }

    function test_addVault() public {
        console2.log("test_addVault");
        IEVault vault1 = IEVault(address(vm.addr(10)));
        IEVault vault2 = IEVault(address(vm.addr(20)));
        IERC20 token = IERC20(address(vm.addr(5)));

        vm.mockCall(
            address(mockEvkFactory),
            abi.encodeWithSelector(mockEvkFactory.isVerified.selector, address(vault1)),
            abi.encode(true)
        );
        vm.mockCall(
            address(mockEvkFactory),
            abi.encodeWithSelector(mockEvkFactory.isVerified.selector, address(vault2)),
            abi.encode(true)
        );

        wrapper.addVault(token, vault1);
        wrapper.addVault(token, vault2);

        // Verify that the vault was added to tokenVaults
        IEVault _vault1 = wrapper.tokenVaults(token, 0);
        IEVault _vault2 = wrapper.tokenVaults(token, 1);
        uint256 vaultCount = wrapper.getVaultCount(token);
        assertEq(vaultCount, 2, "Vault count is incorrect");
        assertEq(address(_vault1), address(vault1), "Vault added incorrectly");
        assertEq(address(_vault2), address(vault2), "Vault added incorrectly");
    }

    function test_removeVault() public {
        console2.log("test_removeVault");
        IERC20 token = IERC20(USDC);

        // check that vault was added before
        uint256 vaultCountBefore = wrapper.getVaultCount(token);
        assertEq(vaultCountBefore, 2, "Vault count is incorrect");

        wrapper.removeVault(token, IEVault(usdcVault1));
        uint256 vaultCountAfter = wrapper.getVaultCount(token);
        assertEq(vaultCountAfter, 1, "Vault is not removed");
    }

    function test_addVault_unverifiedVault() external {
        console2.log("test_addVault_unverifiedVault");
        IEVault vault = IEVault(address(vm.addr(10)));

        vm.mockCall(
            address(mockEvkFactory),
            abi.encodeWithSelector(mockEvkFactory.isVerified.selector, address(vault)),
            abi.encode(false)
        );

        vm.expectRevert(abi.encodeWithSelector(EulerWrapper.UnverifiedVault.selector));
        wrapper.addVault(IERC20(USDC), vault);
    }

    function test_maxFlashLoan() external {
        console2.log("test_maxFlashLoan");
        assertEq(wrapper.maxFlashLoan(USDC), 1_985_258_139_987, "Max flash loan not right");
    }

    function test_flashLoan() external {
        console2.log("test_flashLoan");
        uint256 loan = 100_000e6; // will be used the second vault with enough balance
        bytes memory result = borrower.flashBorrow(USDC, loan);

        // Test the return values passed through the wrapper
        (bytes32 callbackReturn) = abi.decode(result, (bytes32));
        assertEq(uint256(callbackReturn), uint256(borrower.ERC3156PP_CALLBACK_SUCCESS()), "Callback failed");

        // Test the borrower state during the callback
        assertEq(borrower.flashInitiator(), address(borrower));
        assertEq(address(borrower.flashAsset()), address(USDC));
        assertEq(borrower.flashAmount(), loan);
        // The amount we transferred to pay for fees, plus the amount we borrowed
        assertEq(borrower.flashBalance(), loan);
        assertEq(borrower.flashFee(), 0);
    }

    function test_measureFlashLoanGas() public {
        console2.log("test_measureFlashLoanGas");
        uint256 loan = 10e6;
        uint256 fee = wrapper.flashFee(USDC, loan);
        IERC20(USDC).safeTransfer(address(borrower), fee);
        borrower.flashBorrowMeasureGas(USDC, loan, "Euler");
    }
}
