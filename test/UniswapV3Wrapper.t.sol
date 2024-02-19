// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import { PRBTest } from "@prb/test/PRBTest.sol";
import { console2 } from "forge-std/console2.sol";
import { StdCheats } from "forge-std/StdCheats.sol";

import { IERC20Metadata as IERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Registry } from "src/Registry.sol";

import { MockBorrower } from "./MockBorrower.sol";
import { UniswapV3Wrapper } from "../src/uniswapV3/UniswapV3Wrapper.sol";
import { IUniswapV3Factory } from "../src/uniswapV3/interfaces/IUniswapV3Factory.sol";

/// @dev If this is your first time with Forge, read this tutorial in the Foundry Book:
/// https://book.getfoundry.sh/forge/writing-tests
contract UniswapV3WrapperTest is PRBTest, StdCheats {
    UniswapV3Wrapper internal wrapper;
    MockBorrower internal borrower;
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

        Registry registry = new Registry(address(this));
        registry.set("UniswapV3Wrapper", abi.encode(address(factory), weth, usdc, usdt));
        wrapper = new UniswapV3Wrapper(registry);
        borrower = new MockBorrower(wrapper);
    }

    /// @dev Basic test. Run it with `forge test -vvv` to see the console log.
    function test_flashFee() external {
        console2.log("test_flashFee");
        assertEq(wrapper.flashFee(usdc, 100e6), 0.01e6, "Fee not exact USDC");
        assertEq(wrapper.flashFee(usdt, 100e6), 0.01e6, "Fee not exact USDT");
        assertEq(wrapper.flashFee(weth, 1e18), 0.0001e18, "Fee not exact IWETH9 1");
        assertEq(wrapper.flashFee(weth, 10e18), 0.005e18, "Fee not exact IWETH9 2");
        assertEq(wrapper.flashFee(wbtc, 1e8), 0.0005e8, "Fee not exact WBTC");
    }

    function test_maxFlashLoan() external {
        console2.log("test_maxFlashLoan");
        assertEq(wrapper.maxFlashLoan(usdc), 105_711_486.370205e6, "Max flash loan not right");
        assertEq(wrapper.maxFlashLoan(usdt), 96_332_238.568654e6, "Max flash loan not right");
        assertEq(wrapper.maxFlashLoan(weth), 72_346.284100504850288712e18, "Max flash loan not right");
        assertEq(wrapper.maxFlashLoan(wbtc), 2403.63114397e8, "Max flash loan not right");
    }

    function test_flashLoan_USDC() external {
        test_flashLoan(usdc, 100e6);
    }

    function test_flashLoan_USDT() external {
        test_flashLoan(usdt, 100e6);
    }

    function test_flashLoan_WETH() external {
        test_flashLoan(weth, 0.1 ether);
    }

    function test_flashLoan_WBTC() external {
        test_flashLoan(wbtc, 0.1e8);
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

    function test_uniswapV3FlashCallback_permissions() public {
        vm.expectRevert(UniswapV3Wrapper.UnknownPool.selector);
        wrapper.uniswapV3FlashCallback({
            fee0: 0,
            fee1: 0,
            params: abi.encode(address(usdc), address(usdt), uint24(0.0005e6), uint256(0), "")
        });
    }
}
