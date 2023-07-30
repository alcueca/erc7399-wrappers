// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import { PRBTest } from "@prb/test/PRBTest.sol";
import { console2 } from "forge-std/console2.sol";
import { StdCheats } from "forge-std/StdCheats.sol";

import { IFlashLoaner } from "../src/balancer/interfaces/IFlashLoaner.sol";
import { FlashBorrower } from "./FlashBorrower.sol";
import { IERC20, BalancerWrapper } from "../src/balancer/BalancerWrapper.sol";

/// @dev If this is your first time with Forge, read this tutorial in the Foundry Book:
/// https://book.getfoundry.sh/forge/writing-tests
contract BalancerWrapperTest is PRBTest, StdCheats {
    BalancerWrapper internal wrapper;
    FlashBorrower internal borrower;
    IERC20 internal dai;
    IFlashLoaner internal balancer;

    /// @dev A function invoked before each test case is run.
    function setUp() public virtual {
        // Revert if there is no API key.
        string memory alchemyApiKey = vm.envOr("API_KEY_ALCHEMY", string(""));
        if (bytes(alchemyApiKey).length == 0) {
            revert("API_KEY_ALCHEMY variable missing");
        }

        vm.createSelectFork({ urlOrAlias: "mainnet", blockNumber: 16_428_000 });
        balancer = IFlashLoaner(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
        dai = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);

        wrapper = new BalancerWrapper(balancer);
        borrower = new FlashBorrower(wrapper);
        deal(address(dai), address(this), 1e18); // For fees
    }

    /// @dev Basic test. Run it with `forge test -vvv` to see the console log.
    function test_flashFee() external {
        console2.log("test_flashFee");
        assertEq(wrapper.flashFee(dai, 1e18), 0, "Fee not zero");
        assertEq(wrapper.flashFee(dai, type(uint256).max), type(uint256).max, "Fee not max");
    }

    function test_flashLoan() external {
        console2.log("test_flashLoan");
        uint256 loan = 1e18;
        uint256 fee = wrapper.flashFee(dai, loan);
        dai.transfer(address(borrower), fee);
        bytes memory result = borrower.flashBorrow(dai, loan);

        // Test the return values
        (bytes32 callbackReturn) = abi.decode(result, (bytes32));
        assertEq(uint256(callbackReturn), uint256(borrower.ERC3156PP_CALLBACK_SUCCESS()), "Callback failed");

        // Test the borrower state
        assertEq(borrower.flashInitiator(), address(borrower));
        assertEq(address(borrower.flashAsset()), address(dai));
        assertEq(borrower.flashAmount(), loan);
        assertEq(borrower.flashBalance(), loan + fee); // The amount we transferred to pay for fees, plus the amount we
            // borrowed
        assertEq(borrower.flashFee(), fee);
    }
}
