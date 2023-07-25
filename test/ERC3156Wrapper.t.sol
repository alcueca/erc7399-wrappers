// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import { PRBTest } from "@prb/test/PRBTest.sol";
import { console2 } from "forge-std/console2.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import { IERC3156FlashLender } from "lib/erc3156/contracts/interfaces/IERC3156FlashLender.sol";

import { FlashBorrower } from "../src/test/FlashBorrower.sol";
import { IERC20, ERC3156Wrapper } from "../src/erc3156/ERC3156Wrapper.sol";


/// @dev If this is your first time with Forge, read this tutorial in the Foundry Book:
/// https://book.getfoundry.sh/forge/writing-tests
contract ERC3156WrapperTest is PRBTest, StdCheats {
    ERC3156Wrapper internal wrapper;
    FlashBorrower internal borrower;
    IERC20 internal dai;
    IERC3156FlashLender internal makerFlash;

    /// @dev A function invoked before each test case is run.
    function setUp() public virtual {
        // Revert if there is no API key.
        string memory alchemyApiKey = vm.envOr("API_KEY_ALCHEMY", string(""));
        if (bytes(alchemyApiKey).length == 0) {
            revert("API_KEY_ALCHEMY variable missing");
        }

        vm.createSelectFork({ urlOrAlias: "mainnet", blockNumber: 16_428_000 });
        makerFlash = IERC3156FlashLender(0x60744434d6339a6B27d73d9Eda62b6F66a0a04FA);
        dai = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);

        IERC20[] memory assets = new IERC20[](1);
        assets[0] = dai;
        IERC3156FlashLender[] memory lenders = new IERC3156FlashLender[](1);
        lenders[0] = makerFlash;
        wrapper = new ERC3156Wrapper(assets, lenders);
        borrower = new FlashBorrower(wrapper);
    }

    /// @dev Basic test. Run it with `forge test -vvv` to see the console log.
    function test_flashFee() external {
        console2.log("test_flashFee");
        assertEq(wrapper.flashFee(dai, 1e18), 0, "Fee not zero");
        assertEq(wrapper.flashFee(dai, type(uint256).max), type(uint256).max, "Fee not max");
    }

    function test_flashLoan() external {
        console2.log("test_flashLoan");
        uint256 lenderBalance = dai.balanceOf(address(wrapper));
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
        assertEq(borrower.flashBalance(), loan + fee); // The amount we transferred to pay for fees, plus the amount we borrowed
        assertEq(borrower.flashFee(), fee);
        assertEq(dai.balanceOf(address(wrapper)), lenderBalance + fee);
    }
}