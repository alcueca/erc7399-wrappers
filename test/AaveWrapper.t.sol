// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import { PRBTest } from "@prb/test/PRBTest.sol";
import { console2 } from "forge-std/console2.sol";
import { StdCheats } from "forge-std/StdCheats.sol";

import { FunctionCodec } from "../src/utils/FunctionCodec.sol";
import { FlashBorrower } from "../src/test/FlashBorrower.sol";
import { IERC20, AaveWrapper } from "../src/aave/AaveWrapper.sol";
import { IPoolAddressesProvider } from "../src/aave/interfaces/IPoolAddressesProvider.sol";

/// @dev If this is your first time with Forge, read this tutorial in the Foundry Book:
/// https://book.getfoundry.sh/forge/writing-tests
contract AaveWrapperTest is PRBTest, StdCheats {
    using FunctionCodec for *;

    AaveWrapper internal wrapper;
    FlashBorrower internal borrower;
    IERC20 internal dai;
    IPoolAddressesProvider internal provider;

    /// @dev A function invoked before each test case is run.
    function setUp() public virtual {
        // Revert if there is no API key.
        string memory alchemyApiKey = vm.envOr("API_KEY_ALCHEMY", string(""));
        if (bytes(alchemyApiKey).length == 0) {
            revert("API_KEY_ALCHEMY variable missing");
        }

        vm.createSelectFork({ urlOrAlias: "arbitrum_one", blockNumber: 98_674_994 });
        provider = IPoolAddressesProvider(0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb);
        dai = IERC20(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1);

        wrapper = new AaveWrapper(provider);
        borrower = new FlashBorrower(wrapper);
        deal(address(dai), address(this), 1e18); // For fees
    }

    /// @dev Basic test. Run it with `forge test -vvv` to see the console log.
    function test_flashFee() external {
        console2.log("test_flashFee");
        assertEq(wrapper.flashFee(dai, 1e18), 5e14, "Fee not right");
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

        // Test the wrapper state (return bytes should be cleaned up)
        assertEq(vm.load(address(wrapper), bytes32(uint256(1))), "");
    }

    function test_flashLoan_void() external {
        console2.log("test_flashLoan_void");
        uint256 loan = 1e18;
        uint256 fee = wrapper.flashFee(dai, loan);
        dai.transfer(address(borrower), fee);

        vm.record();
        bytes memory result = borrower.flashBorrowVoid(dai, loan);

        // Test the return values
        assertEq(result, "", "Void result");

        (, bytes32[] memory writeSlots) = vm.accesses(address(wrapper));
        assertEq(writeSlots.length, 0, "writeSlots");
    }

    function test_executeOperation() public {
        AaveWrapper.Data memory data = AaveWrapper.Data({
            loanReceiver: address(this),
            initiator: address(this),
            callback: this._voidCallback,
            initiatorData: ""
        });

        deal(address(dai), address(wrapper), 1e18);
        vm.prank(provider.getPool());
        vm.record();
        wrapper.executeOperation({
            asset: address(dai),
            amount: 1e18,
            fee: 0,
            aaveInitiator: address(wrapper),
            params: abi.encode(data)
        });

        (, bytes32[] memory writeSlots) = vm.accesses(address(wrapper));
        assertEq(writeSlots.length, 0, "writeSlots");
    }

    function _voidCallback(
        address,
        address,
        IERC20,
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
