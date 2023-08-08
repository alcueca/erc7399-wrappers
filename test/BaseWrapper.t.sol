// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import { PRBTest } from "@prb/test/PRBTest.sol";
import { console2 } from "forge-std/console2.sol";
import { StdCheats } from "forge-std/StdCheats.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";

import { FlashBorrower } from "./FlashBorrower.sol";

import { BaseWrapper } from "src/BaseWrapper.sol";

/// @dev If this is your first time with Forge, read this tutorial in the Foundry Book:
/// https://book.getfoundry.sh/forge/writing-tests
contract BaseWrapperTest is PRBTest, StdCheats {
    FooWrapper internal wrapper;
    FooLender internal lender;
    FlashBorrower internal borrower;
    address internal dai;

    /// @dev A function invoked before each test case is run.
    function setUp() public virtual {
        // Revert if there is no API key.
        string memory alchemyApiKey = vm.envOr("API_KEY_ALCHEMY", string(""));
        if (bytes(alchemyApiKey).length == 0) {
            revert("API_KEY_ALCHEMY variable missing");
        }

        vm.createSelectFork({ urlOrAlias: "arbitrum_one", blockNumber: 98_674_994 });
        dai = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;

        lender = new FooLender();
        deal(address(dai), address(lender), 10_000_000e18);
        wrapper = new FooWrapper(lender);
        borrower = new FlashBorrower(wrapper);
        deal(address(dai), address(this), 1e18); // For fees
    }

    function test_flashLoan() external {
        console2.log("test_flashLoan");
        uint256 loan = 1e18;
        uint256 fee = wrapper.flashFee(dai, loan);
        ERC20(dai).transfer(address(borrower), fee);
        bytes memory result = borrower.flashBorrow(dai, loan);

        // Test the return values
        (bytes32 callbackReturn) = abi.decode(result, (bytes32));
        assertEq(uint256(callbackReturn), uint256(borrower.ERC3156PP_CALLBACK_SUCCESS()), "Callback failed");

        // Test the wrapper state (return bytes should be cleaned up)
        assertEq(vm.load(address(wrapper), bytes32(uint256(0))), "");
    }

    function test_flashLoan_void() external {
        console2.log("test_flashLoan_void");
        uint256 loan = 1e18;
        uint256 fee = wrapper.flashFee(dai, loan);
        ERC20(dai).transfer(address(borrower), fee);

        vm.record();
        bytes memory result = borrower.flashBorrowVoid(dai, loan);

        // Test the return values
        assertEq(result, "", "Void result");

        // Test the wrapper state, no storage writes on void results
        (, bytes32[] memory writeSlots) = vm.accesses(address(wrapper));
        assertEq(writeSlots.length, 0, "writeSlots");
    }

    function _voidCallback(
        address,
        address,
        ERC20,
        uint256,
        uint256,
        bytes memory
    )
        external
        pure
        returns (bytes memory)
    {
        return "";
    }
}

contract FooLender {
    function flashLoan(
        address asset,
        uint256 amount,
        bytes memory data,
        function(address,bytes memory) external callback
    )
        external
    {
        uint256 balance = ERC20(asset).balanceOf(address(this));
        ERC20(asset).transfer(msg.sender, amount);
        callback(asset, data);
        require(ERC20(asset).balanceOf(address(this)) >= balance, "FooLender: insufficient balance");
    }
}

contract FooWrapper is BaseWrapper {
    FooLender immutable lender;

    constructor(FooLender lender_) {
        lender = lender_;
    }

    function _flashLoan(address asset, uint256 amount, bytes memory params) internal virtual override {
        lender.flashLoan(asset, amount, params, this.flashLoanCallback);
    }

    function flashLoanCallback(address asset, bytes memory params) external virtual {
        _bridgeToCallback(asset, ERC20(asset).balanceOf(address(this)), 0, params);
        ERC20(asset).transfer(msg.sender, ERC20(asset).balanceOf(address(this)));
    }

    function maxFlashLoan(address token) external view override returns (uint256) { }

    function flashFee(address token, uint256 amount) external view override returns (uint256) { }
}
