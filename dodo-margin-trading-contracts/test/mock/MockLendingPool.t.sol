/*

    Copyright 2023 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0*/

pragma solidity 0.8.15;

import "../Context.t.sol";

contract MockLendingPoolTest is Context {
    function setUp() public {
        contextBasic();
        approveAllToken();
    }

    function testDeposit() public {
        vm.startPrank(user1);
        faucet(address(depositToken), user1, 100 ether);
        lendingPool.deposit(address(depositToken), 100 ether, user1, uint16(0));
        vm.stopPrank();
        sinkUserTokenBalance(user1);
        assertEq(aToken.balanceOf(user1), 100 ether);
    }

    function testWithdraw() public {
        vm.startPrank(user1);
        faucet(address(depositToken), user1, 100 ether);
        lendingPool.deposit(address(depositToken), 100 ether, user1, uint16(0));
        lendingPool.withdraw(address(depositToken), 50 ether, user1);
        vm.stopPrank();
        sinkUserTokenBalance(user1);
        assertEq(aToken.balanceOf(user1), 50 ether);
    }

    function testBorrow() public {
        faucetWeth(address(lendingPool), 100000 ether);

        vm.startPrank(user1);
        lendingPool.borrow(address(weth), 100 ether, user1);
        vm.stopPrank();
        sinkUserTokenBalance(user1);
        assertEq(debtToken.balanceOf(user1), 100 ether);
    }

    function testRepay() public {
        faucetWeth(address(lendingPool), 100000 ether);

        vm.startPrank(user1);
        lendingPool.borrow(address(weth), 100 ether, user1);
        lendingPool.repay(address(weth), 50 ether, 1, user1);
        vm.stopPrank();
        sinkUserTokenBalance(user1);
        assertEq(debtToken.balanceOf(user1), 50 ether);
    }

    function testLiquidationCall() public {
        faucetWeth(address(lendingPool), 100000 ether);
        faucetWeth(address(user2), 100 ether);
        faucet(address(depositToken), address(lendingPool), 100000 ether);

        vm.startPrank(user1);
        faucet(address(depositToken), user1, 100 ether);
        lendingPool.deposit(address(depositToken), 100 ether, user1, uint16(0));
        lendingPool.borrow(address(weth), 100 ether, user1);
        vm.stopPrank();

        vm.startPrank(user2);
        lendingPool.liquidationCall(address(depositToken), address(debtToken), user1, 50 ether, true);
        vm.stopPrank();

        vm.startPrank(user2);
        lendingPool.liquidationCall(address(depositToken), address(debtToken), user1, 25 ether, false);
        vm.stopPrank();

        sinkUserTokenBalance(user1);
        sinkUserTokenBalance(user2);

        assertEq(aToken.balanceOf(user1), 100 ether - (50 ether * 105) / 100 - (25 ether * 105) / 100);
    }
}
