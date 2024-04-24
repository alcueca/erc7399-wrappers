// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { StdCheats } from "forge-std/StdCheats.sol";

import { IERC20Metadata as IERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Registry } from "src/Registry.sol";

import { MockBorrower } from "./MockBorrower.sol";
import { UniswapV3Wrapper } from "../src/uniswapV3/UniswapV3Wrapper.sol";
import { IUniswapV3Factory } from "../src/uniswapV3/interfaces/IUniswapV3Factory.sol";
import { Arrays } from "src/utils/Arrays.sol";

/// @dev If this is your first time with Forge, read this tutorial in the Foundry Book:
/// https://book.getfoundry.sh/forge/writing-tests
contract UniswapV3WrapperLiquidityTest is Test {
    using Arrays for *;

    UniswapV3Wrapper internal wrapper;
    MockBorrower internal borrower;
    address internal usdc;
    address internal usdt;
    address internal weth;
    address internal rseth;
    IUniswapV3Factory internal factory;

    /// @dev A function invoked before each test case is run.
    function setUp() public virtual {
        // Revert if there is no API key.
        string memory alchemyApiKey = vm.envOr("API_KEY_ALCHEMY", string(""));
        if (bytes(alchemyApiKey).length == 0) {
            revert("API_KEY_ALCHEMY variable missing");
        }

        vm.createSelectFork({ urlOrAlias: "arbitrum_one", blockNumber: 204_382_544 });
        factory = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
        usdc = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
        weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
        rseth = 0x4186BFC76E2E237523CBC30FD220FE055156b41F;

        Registry registry = new Registry(address(this).toArray(), address(this).toArray());
        registry.set("UniswapV3Wrapper", abi.encode(address(factory), weth, usdc));
        wrapper = new UniswapV3Wrapper(registry);
        borrower = new MockBorrower(wrapper);
    }

    /// @dev Basic test. Run it with `forge test -vvv` to see the console log.
    function test_flashFee() external {
        console2.log("test_flashFee");
        assertEqDecimal(wrapper.flashFee(rseth, 1e18), 0.003e18, 18, "Fee not exact");
    }

    function test_maxFlashLoan() external {
        console2.log("test_maxFlashLoan");
        assertEqDecimal(wrapper.maxFlashLoan(rseth), 8.986835885934438101e18, 18, "Max flash loan not right");
    }

    function test_flashLoan_RSETH() external {
        test_flashLoan(rseth, 5e18);
    }

    function test_flashLoan(address token, uint256 loan) internal {
        console2.log(string.concat("test_flashLoan: ", IERC20(token).symbol()));
        uint256 fee = wrapper.flashFee(token, loan);
        deal(address(token), address(borrower), fee);
        bytes memory result = borrower.flashBorrow(token, loan);

        // Test the return values passed through the wrapper
        (bytes32 callbackReturn) = abi.decode(result, (bytes32));
        assertEq(uint256(callbackReturn), uint256(borrower.ERC3156PP_CALLBACK_SUCCESS()), "Callback failed");

        // Test the borrower state during the callback
        assertEq(borrower.flashInitiator(), address(borrower), "flashInitiator");
        assertEq(address(borrower.flashAsset()), address(token), "flashAsset");
        assertEq(borrower.flashAmount(), loan, "flashAmount");
        // The amount we transferred to pay for fees, plus the amount we borrowed
        assertEq(borrower.flashBalance(), loan + fee, "flashBalance");
        assertEq(borrower.flashFee(), fee, "flashFee");
    }
}
