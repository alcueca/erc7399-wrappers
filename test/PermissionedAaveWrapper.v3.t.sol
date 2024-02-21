// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import { PRBTest } from "@prb/test/PRBTest.sol";
import { console2 } from "forge-std/console2.sol";
import { StdCheats } from "forge-std/StdCheats.sol";

import { Registry } from "src/Registry.sol";

import { IERC20Metadata as IERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { MockBorrower, IERC7399 } from "./MockBorrower.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { PermissionedAaveWrapper, AaveWrapper } from "../src/aave/PermissionedAaveWrapper.sol";
import { Arrays } from "src/utils/Arrays.sol";
import { IPoolAddressesProviderV3 } from "../src/aave/interfaces/IPoolAddressesProviderV3.sol";

/// @dev If this is your first time with Forge, read this tutorial in the Foundry Book:
/// https://book.getfoundry.sh/forge/writing-tests
contract PermissionedAaveWrapperTest is PRBTest, StdCheats {
    using Arrays for *;
    using SafeERC20 for IERC20;

    PermissionedAaveWrapper internal wrapper;
    MockBorrower internal borrower;
    address internal dai;
    IPoolAddressesProviderV3 internal provider;

    address internal owner = makeAddr("owner");

    /// @dev A function invoked before each test case is run.
    function setUp() public virtual {
        // Revert if there is no API key.
        string memory alchemyApiKey = vm.envOr("API_KEY_ALCHEMY", string(""));
        if (bytes(alchemyApiKey).length == 0) {
            revert("API_KEY_ALCHEMY variable missing");
        }

        vm.createSelectFork({ urlOrAlias: "arbitrum_one", blockNumber: 98_674_994 });
        provider = IPoolAddressesProviderV3(0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb);
        dai = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;

        Registry registry = new Registry(address(this).toArray(), address(this).toArray());
        registry.set(
            "AaveV3Wrapper", abi.encode(provider.getPool(), address(provider), provider.getPoolDataProvider(), false)
        );

        borrower = new MockBorrower(IERC7399(address(0)));
        wrapper = new PermissionedAaveWrapper(owner, address(borrower), registry, "AaveV3");
        borrower.setLender(wrapper);
    }

    /// @dev Basic test. Run it with `forge test -vvv` to see the console log.
    function test_flashFee() external {
        console2.log("test_flashFee");
        assertEq(wrapper.flashFee(dai, 1e18), 0, "Fee not right");
    }

    function test_maxFlashLoan() external {
        console2.log("test_maxFlashLoan");
        assertEq(wrapper.maxFlashLoan(dai), 3_258_387.712396344524653246e18, "Max flash loan not right");
    }

    function test_flashLoan() external {
        console2.log("test_flashLoan");
        vm.mockCall(
            provider.getACLManager(),
            abi.encodeWithSelector(IACLManager.isFlashBorrower.selector, wrapper),
            abi.encode(true)
        );

        uint256 loan = 1e18;
        uint256 fee = wrapper.flashFee(dai, loan);
        IERC20(dai).safeTransfer(address(borrower), fee);
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

        vm.prank(provider.getPool());
        vm.expectRevert(AaveWrapper.NotInitiator.selector);
        wrapper.executeOperation({
            assets: address(dai).toArray(),
            amounts: 1e18.toArray(),
            fees: 0.toArray(),
            initiator: address(0x666),
            params: ""
        });
    }

    function test_flashLoan_permissions() external {
        console2.log("test_flashLoan_permissions");
        borrower = new MockBorrower(wrapper);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, borrower, wrapper.BORROWER()
            )
        );
        borrower.flashBorrow(dai, 1e18);
    }
}

interface IACLManager {
    function isFlashBorrower(address) external view returns (bool);
}
