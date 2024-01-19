// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import { PRBTest } from "@prb/test/PRBTest.sol";
import { console2 } from "forge-std/console2.sol";
import { StdCheats } from "forge-std/StdCheats.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";

import { Arrays } from "src/utils/Arrays.sol";

import { IDolomiteMargin } from "../src/dolomite/interfaces/IDolomiteMargin.sol";
import { MockBorrower } from "./MockBorrower.sol";
import { DolomiteWrapper } from "../src/dolomite/DolomiteWrapper.sol";

/// @dev If this is your first time with Forge, read this tutorial in the Foundry Book:
/// https://book.getfoundry.sh/forge/writing-tests
contract DolomiteWrapperTest is PRBTest, StdCheats {
    using Arrays for uint256;
    using Arrays for address;

    DolomiteWrapper internal wrapper;
    MockBorrower internal borrower;
    address internal wbtc;
    IDolomiteMargin internal dolomite;

    /// @dev A function invoked before each test case is run.
    function setUp() public virtual {
        // Revert if there is no API key.
        string memory alchemyApiKey = vm.envOr("API_KEY_ALCHEMY", string(""));
        if (bytes(alchemyApiKey).length == 0) {
            revert("API_KEY_ALCHEMY variable missing");
        }

        vm.createSelectFork({ urlOrAlias: "arbitrum_one", blockNumber: 172_018_795 });
        dolomite = IDolomiteMargin(0x6Bd780E7fDf01D77e4d475c821f1e7AE05409072);
        wbtc = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;

        wrapper = new DolomiteWrapper(dolomite);
        borrower = new MockBorrower(wrapper);
    }

    /// @dev Basic test. Run it with `forge test -vvv` to see the console log.
    function test_flashFee() external {
        console2.log("test_flashFee");
        assertEq(wrapper.flashFee(wbtc, 1e8), 0, "Fee not zero");
    }

    function test_maxFlashLoan() external {
        console2.log("test_maxFlashLoan");
        assertEq(wrapper.maxFlashLoan(wbtc), 89.50596499e8, "Max flash loan not right");
    }

    function test_flashLoan() external {
        console2.log("test_flashLoan");
        uint256 loan = 10e8;
        uint256 fee = wrapper.flashFee(wbtc, loan);
        ERC20(wbtc).transfer(address(borrower), fee);
        bytes memory result = borrower.flashBorrow(wbtc, loan);

        // Test the return values passed through the wrapper
        (bytes32 callbackReturn) = abi.decode(result, (bytes32));
        assertEq(uint256(callbackReturn), uint256(borrower.ERC3156PP_CALLBACK_SUCCESS()), "Callback failed");

        // Test the borrower state during the callback
        assertEq(borrower.flashInitiator(), address(borrower));
        assertEq(address(borrower.flashAsset()), address(wbtc));
        assertEq(borrower.flashAmount(), loan);
        assertEq(borrower.flashBalance(), loan + fee); // The amount we transferred to pay for fees, plus the amount we
        // borrowed
        assertEq(borrower.flashFee(), fee);
    }

    function test_receiveFlashLoan_permissions() public {
        IDolomiteMargin.Info memory accountInfo;

        vm.expectRevert(DolomiteWrapper.NotSelf.selector);
        wrapper.callFunction(address(this), accountInfo, "");

        vm.expectRevert(DolomiteWrapper.NotDolomite.selector);
        wrapper.callFunction(address(wrapper), accountInfo, "");

        vm.prank(address(dolomite));
        vm.expectRevert(DolomiteWrapper.HashMismatch.selector);
        wrapper.callFunction(address(wrapper), accountInfo, "");
    }
}
