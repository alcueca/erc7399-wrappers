// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import { PRBTest } from "@prb/test/PRBTest.sol";
import { console2 } from "forge-std/console2.sol";
import { StdCheats } from "forge-std/StdCheats.sol";

import { SafeTransferLib, ERC20 } from "lib/solmate/src/utils/SafeTransferLib.sol";
import { WETH } from "solmate/tokens/WETH.sol";
import { Registry } from "lib/registry/src/Registry.sol";
import { Arrays } from "src/utils/Arrays.sol";

import { IFlashLoaner } from "../src/balancer/interfaces/IFlashLoaner.sol";
import { IComptroller } from "../src/compound/interfaces/IComptroller.sol";
import { ICToken } from "../src/compound/interfaces/ICToken.sol";
import { MockBorrower } from "./MockBorrower.sol";
import { CompoundWrapper } from "../src/compound/CompoundWrapper.sol";

/// @dev If this is your first time with Forge, read this tutorial in the Foundry Book:
/// https://book.getfoundry.sh/forge/writing-tests
contract CompoundWrapperTest is PRBTest, StdCheats {
    using Arrays for uint256;
    using Arrays for address;
    using SafeTransferLib for ERC20;

    CompoundWrapper internal wrapper;
    MockBorrower internal borrower;
    address internal dai;
    IFlashLoaner internal balancer;

    IComptroller internal comptroller;
    WETH internal nativeToken;
    ERC20 internal intermediateToken;

    /// @dev A function invoked before each test case is run.
    function setUp() public virtual {
        // Revert if there is no API key.
        string memory alchemyApiKey = vm.envOr("API_KEY_ALCHEMY", string(""));
        if (bytes(alchemyApiKey).length == 0) {
            revert("API_KEY_ALCHEMY variable missing");
        }

        vm.createSelectFork({ urlOrAlias: "mainnet", blockNumber: 16_428_000 });
        balancer = IFlashLoaner(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
        dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

        comptroller = IComptroller(0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B);
        nativeToken = WETH(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
        intermediateToken = ERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // USDC

        Registry registry = new Registry(address(this));
        registry.set("CompoundWrapper", abi.encode(balancer, comptroller, nativeToken, intermediateToken));

        wrapper = new CompoundWrapper(registry, "CompoundWrapper");
        wrapper.update();
        borrower = new MockBorrower(wrapper);
        deal(address(dai), address(this), 1e18); // For fees
    }

    /// @dev Basic test. Run it with `forge test -vvv` to see the console log.
    function test_flashFee() external {
        console2.log("test_flashFee");
        assertEq(wrapper.flashFee(dai, 1e18), 0, "Fee not zero");
    }

    function test_maxFlashLoan() external {
        console2.log("test_maxFlashLoan");
        assertEq(wrapper.maxFlashLoan(dai), 292_737_884.916639393672887465e18, "Max flash loan not right");
    }

    function test_flashLoan() external {
        console2.log("test_flashLoan");
        uint256 loan = 1e18;
        uint256 fee = wrapper.flashFee(dai, loan);
        ERC20(dai).safeTransfer(address(borrower), fee);
        bytes memory result = borrower.flashBorrow(dai, loan);

        // Test the return values passed through the wrapper
        (bytes32 callbackReturn) = abi.decode(result, (bytes32));
        assertEq(uint256(callbackReturn), uint256(borrower.ERC3156PP_CALLBACK_SUCCESS()), "Callback failed");

        // Test the borrower state during the callback
        assertEq(borrower.flashInitiator(), address(borrower));
        assertEq(address(borrower.flashAsset()), address(dai));
        assertEq(borrower.flashAmount(), loan);
        assertEq(borrower.flashBalance(), loan + fee); // The amount we transferred to pay for fees, plus the amount we
            // borrowed
        assertEq(borrower.flashFee(), fee);
    }

    function test_receiveFlashLoan_permissions() public {
        vm.expectRevert(CompoundWrapper.NotBalancer.selector);
        wrapper.receiveFlashLoan(address(dai).toArray(), uint256(1e18).toArray(), uint256(0).toArray(), "");

        vm.prank(address(balancer));
        vm.expectRevert(CompoundWrapper.HashMismatch.selector);
        wrapper.receiveFlashLoan(address(dai).toArray(), uint256(1e18).toArray(), uint256(0).toArray(), "");
    }

    function test_setCToken() public {
        vm.expectRevert(CompoundWrapper.InvalidMarket.selector);
        wrapper.setCToken(ERC20(dai), ICToken(address(0x666)));

        wrapper.setCToken(ERC20(dai), ICToken(address(0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643)));
    }
}
