// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import { PRBTest } from "@prb/test/PRBTest.sol";
import { console2 } from "forge-std/console2.sol";
import { StdCheats } from "forge-std/StdCheats.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";

import { FlashBorrower } from "./FlashBorrower.sol";
import { UniswapV3Wrapper } from "../src/uniswapV3/UniswapV3Wrapper.sol";
import { IUniswapV3Factory } from "../src/uniswapV3/interfaces/IUniswapV3Factory.sol";

/// @dev If this is your first time with Forge, read this tutorial in the Foundry Book:
/// https://book.getfoundry.sh/forge/writing-tests
contract UniswapV3WrapperTest is PRBTest, StdCheats {
    UniswapV3Wrapper internal wrapper;
    FlashBorrower internal borrower;
    address internal usdc;
    address internal usdt;
    address internal weth;
    address internal wbtc;
    IUniswapV3Factory internal factory;

    /// @dev A function invoked before each test case is run.
    function setUp() public virtual {
        // Revert if there is no API key.
        string memory alchemyApiKey = vm.envOr("API_KEY_ALCHEMY", string(""));
        if (bytes(alchemyApiKey).length == 0) {
            revert("API_KEY_ALCHEMY variable missing");
        }

        vm.createSelectFork({ urlOrAlias: "mainnet", blockNumber: 17_784_898 });
        factory = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
        usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        usdt = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
        weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        wbtc = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

        wrapper = new UniswapV3Wrapper(address(factory), weth, usdc, usdt);
        borrower = new FlashBorrower(wrapper);
        deal(address(usdc), address(this), 1e6); // For fees
    }

    /// @dev Basic test. Run it with `forge test -vvv` to see the console log.
    function test_flashFee() external {
        console2.log("test_flashFee");
        assertEq(wrapper.flashFee(usdc, 100e6), 0.01e6, "Fee not exact USDC");
        assertEq(wrapper.flashFee(usdt, 100e6), 0.01e6, "Fee not exact USDT");
        assertEq(wrapper.flashFee(weth, 1e18), 0.0001e18, "Fee not exact WETH 1");
        assertEq(wrapper.flashFee(weth, 10e18), 0.005e18, "Fee not exact WETH 2");
        assertEq(wrapper.flashFee(wbtc, 1e8), 0.0005e8, "Fee not exact WBTC");
    }

    function test_maxFlashLoan() external {
        console2.log("test_maxFlashLoan");
        assertEq(wrapper.maxFlashLoan(usdc), 105_711_486.370205e6, "Max flash loan not right");
        assertEq(wrapper.maxFlashLoan(usdt), 96_332_238.568654e6, "Max flash loan not right");
        assertEq(wrapper.maxFlashLoan(weth), 72_346.284100504850288712e18, "Max flash loan not right");
        assertEq(wrapper.maxFlashLoan(wbtc), 2403.63114397e8, "Max flash loan not right");
    }

    function test_flashLoan() external {
        console2.log("test_flashLoan");
        uint256 loan = 100e6;
        uint256 fee = wrapper.flashFee(usdc, loan);
        ERC20(usdc).transfer(address(borrower), fee);
        bytes memory result = borrower.flashBorrow(usdc, loan);

        // Test the return values
        (bytes32 callbackReturn) = abi.decode(result, (bytes32));
        assertEq(uint256(callbackReturn), uint256(borrower.ERC3156PP_CALLBACK_SUCCESS()), "Callback failed");

        // Test the borrower state
        assertEq(borrower.flashInitiator(), address(borrower), "flashInitiator");
        assertEq(address(borrower.flashAsset()), address(usdc), "flashAsset");
        assertEq(borrower.flashAmount(), loan, "flashAmount");
        // The amount we transferred to pay for fees, plus the amount we borrowed
        assertEq(borrower.flashBalance(), loan + fee, "flashBalance");
        assertEq(borrower.flashFee(), fee, "flashFee");
    }

    function test_uniswapV3FlashCallback_permissions() public {
        vm.expectRevert("UniswapV3Wrapper: Only active pool");
        wrapper.uniswapV3FlashCallback({ fee0: 0, fee1: 0, params: "" });
    }
}
