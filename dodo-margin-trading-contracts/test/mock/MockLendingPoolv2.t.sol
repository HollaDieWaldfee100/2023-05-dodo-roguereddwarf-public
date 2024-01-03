/*

    Copyright 2023 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0*/

pragma solidity 0.8.15;

import "../Context.t.sol";

contract MocklendingPoolV2Test is Context {
    function setUp() public {
        contextBasicV2();
        approveAllTokenV2();
    }

    function testDeposit() public {
        vm.startPrank(user1);
        faucet(address(dai), user1, 100 ether);
        lendingPoolV2.deposit(address(dai), 100 ether, user1, uint16(0));
        vm.stopPrank();
        sinkUserTokenBalanceV2(user1);
        assertEq(daiAToken.balanceOf(user1), 100 ether);
    }

    function testWithdraw() public {
        vm.startPrank(user1);
        faucet(address(dai), user1, 100 ether);
        lendingPoolV2.deposit(address(dai), 100 ether, user1, uint16(0));
        lendingPoolV2.withdraw(address(dai), 50 ether, user1);
        vm.stopPrank();
        sinkUserTokenBalanceV2(user1);
        assertEq(daiAToken.balanceOf(user1), 50 ether);
    }

    function testBorrow() public {
        faucetWeth(address(lendingPoolV2), 100000 ether);

        vm.startPrank(user1);
        lendingPoolV2.borrow(address(weth), 100 ether, user1);
        vm.stopPrank();
        sinkUserTokenBalanceV2(user1);
        assertEq(wethDebtToken.balanceOf(user1), 100 ether);
    }

    function testRepay() public {
        faucetWeth(address(lendingPoolV2), 100000 ether);

        vm.startPrank(user1);
        lendingPoolV2.borrow(address(weth), 100 ether, user1);
        lendingPoolV2.repay(address(weth), 50 ether, 1, user1);
        vm.stopPrank();
        sinkUserTokenBalanceV2(user1);
        assertEq(wethDebtToken.balanceOf(user1), 50 ether);
    }

    function testLiquidationCall() public {
        faucetWeth(address(lendingPoolV2), 100000 ether);
        faucet(address(dai), address(lendingPoolV2), 100000 ether);
        faucetWeth(address(user2), 100 ether);

        vm.startPrank(user1);
        faucet(address(dai), user1, 100 ether);
        lendingPoolV2.deposit(address(dai), 100 ether, user1, uint16(0));
        lendingPoolV2.borrow(address(weth), 100 ether, user1);
        vm.stopPrank();

        vm.startPrank(user2);
        lendingPoolV2.liquidationCall(address(weth), address(wethDebtToken), user1, 50 ether, true);
        vm.stopPrank();

        vm.startPrank(user2);
        lendingPoolV2.liquidationCall(address(weth), address(wethDebtToken), user1, 25 ether, false);
        vm.stopPrank();

        sinkUserTokenBalanceV2(user1);
        sinkUserTokenBalanceV2(user2);

        assertEq(daiAToken.balanceOf(user1), 100 ether - (50 ether * 105) / 100 - (25 ether * 105) / 100);
    }
}
