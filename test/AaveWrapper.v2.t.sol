// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import { PRBTest } from "@prb/test/PRBTest.sol";
import { console2 } from "forge-std/console2.sol";
import { StdCheats } from "forge-std/StdCheats.sol";

import { Registry } from "lib/registry/src/Registry.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";

import { MockBorrower } from "./MockBorrower.sol";
import { AaveWrapper } from "../src/aave/AaveWrapper.sol";
import { Arrays } from "src/utils/Arrays.sol";
import { IPoolAddressesProviderV2 } from "../src/aave/interfaces/IPoolAddressesProviderV2.sol";
import { IPoolDataProvider } from "../src/aave/interfaces/IPoolDataProvider.sol";

/// @dev If this is your first time with Forge, read this tutorial in the Foundry Book:
/// https://book.getfoundry.sh/forge/writing-tests
contract AaveWrapperTest is PRBTest, StdCheats {
    using Arrays for *;

    AaveWrapper internal wrapper;
    MockBorrower internal borrower;
    address internal dai;
    IPoolAddressesProviderV2 internal provider;

    /// @dev A function invoked before each test case is run.
    function setUp() public virtual {
        // Revert if there is no API key.
        string memory alchemyApiKey = vm.envOr("API_KEY_ALCHEMY", string(""));
        if (bytes(alchemyApiKey).length == 0) {
            revert("API_KEY_ALCHEMY variable missing");
        }

        vm.createSelectFork({ urlOrAlias: "polygon", blockNumber: 49_648_233 });
        provider = IPoolAddressesProviderV2(0xd05e3E715d945B59290df0ae8eF85c1BdB684744);
        dai = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;

        Registry registry = new Registry(address(this));
        registry.set(
            "AaveV2Wrapper",
            abi.encode(
                provider.getLendingPool(),
                address(provider),
                IPoolDataProvider(0x7551b5D2763519d4e37e8B81929D336De671d46d),
                true
            )
        );

        wrapper = new AaveWrapper(registry, "AaveV2");
        borrower = new MockBorrower(wrapper);
        deal(address(dai), address(this), 1e18); // For fees
    }

    /// @dev Basic test. Run it with `forge test -vvv` to see the console log.
    function test_flashFee() external {
        console2.log("test_flashFee");
        assertEq(wrapper.flashFee(dai, 1e18), 9e14, "Fee not right");
    }

    function test_maxFlashLoan() external {
        console2.log("test_maxFlashLoan");
        assertEq(wrapper.maxFlashLoan(dai), 4_007_105.98277662542473966e18, "Max flash loan not right");
    }

    function test_flashLoan() external {
        console2.log("test_flashLoan");
        uint256 loan = 1e18;
        uint256 fee = wrapper.flashFee(dai, loan);
        ERC20(dai).transfer(address(borrower), fee);
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

    function test_executeOperation_permissions() public {
        vm.expectRevert(AaveWrapper.NotPool.selector);
        wrapper.executeOperation({
            assets: address(dai).toArray(),
            amounts: 1e18.toArray(),
            fees: 0.toArray(),
            initiator: address(wrapper),
            params: ""
        });

        vm.prank(provider.getLendingPool());
        vm.expectRevert(AaveWrapper.NotInitiator.selector);
        wrapper.executeOperation({
            assets: address(dai).toArray(),
            amounts: 1e18.toArray(),
            fees: 0.toArray(),
            initiator: address(0x666),
            params: ""
        });
    }
}
