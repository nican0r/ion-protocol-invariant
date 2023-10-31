// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { WstEthHandler } from "src/flash/handlers/WstEthHandler.sol";
import { Whitelist } from "src/Whitelist.sol";

import { IonPoolSharedSetup } from "test/helpers/IonPoolSharedSetup.sol";
import { ERC20PresetMinterPauser } from "test/helpers/ERC20PresetMinterPauser.sol";

import { IUniswapV3Factory } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

contract WstEthHandler_Test is IonPoolSharedSetup {
    WstEthHandler wstEthHandler;

    uint8 ilkIndex = 0;

    function setUp() public override {
        super.setUp();

        // Ignore Uniswap args since they will be tested through forks
        wstEthHandler =
        new WstEthHandler(ilkIndex, ionPool, gemJoins[ilkIndex], Whitelist(whitelist), IUniswapV3Factory(address(1)), IUniswapV3Pool(address(1)), 500);

        // Remove debt ceiling for this test
        for (uint8 i = 0; i < ionPool.ilkCount(); i++) {
            ionPool.updateIlkDebtCeiling(i, type(uint256).max);
        }

        ERC20PresetMinterPauser(_getUnderlying()).mint(lender1, INITIAL_LENDER_UNDERLYING_BALANCE);

        vm.startPrank(lender1);
        underlying.approve(address(ionPool), type(uint256).max);
        ionPool.supply(lender1, 1e18, new bytes32[](0));
        vm.stopPrank();
    }

    function test_DepositAndBorrow() external {
        uint256 depositAmount = 1e18; // in wstEth
        uint256 borrowAmount = 0.5e18; // in weth

        wstEth.mint(address(this), depositAmount);
        wstEth.approve(address(wstEthHandler), depositAmount);
        ionPool.addOperator(address(wstEthHandler));

        assertEq(underlying.balanceOf(address(this)), 0);
        assertEq(wstEth.balanceOf(address(this)), depositAmount);

        wstEthHandler.depositAndBorrow(depositAmount, borrowAmount, new bytes32[](0));

        assertEq(underlying.balanceOf(address(this)), borrowAmount);
        assertEq(wstEth.balanceOf(address(this)), 0);
    }

    function test_RepayAndWithdraw() external {
        uint256 depositAmount = 1e18; // in wstEth
        uint256 borrowAmount = 0.5e18; // in weth

        wstEth.mint(address(this), depositAmount);
        wstEth.approve(address(wstEthHandler), depositAmount);
        ionPool.addOperator(address(wstEthHandler));

        wstEthHandler.depositAndBorrow(depositAmount, borrowAmount, new bytes32[](0));

        underlying.approve(address(wstEthHandler), borrowAmount);

        assertEq(underlying.balanceOf(address(this)), borrowAmount);
        assertEq(wstEth.balanceOf(address(this)), 0);

        wstEthHandler.repayAndWithdraw(borrowAmount, depositAmount);

        assertEq(underlying.balanceOf(address(this)), 0);
        assertEq(wstEth.balanceOf(address(this)), depositAmount);
    }

    function _getDebtCeiling(uint8) internal pure override returns (uint256) {
        return type(uint256).max;
    }
}