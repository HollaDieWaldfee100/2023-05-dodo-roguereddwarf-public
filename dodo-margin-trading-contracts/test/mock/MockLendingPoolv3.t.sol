/*

    Copyright 2023 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0*/

pragma solidity 0.8.15;

import "../Context.t.sol";

contract MocklendingPoolV3Test is Context {
    function setUp() public {
        contextBasicV2();
        approveAllTokenV2();
    }

    function testDeposit() public {
        vm.startPrank(user1);
        faucet(address(dai), user1, 100 ether);
        lendingPoolV3.deposit(address(dai), 100 ether, user1, uint16(0));
        vm.stopPrank();
        sinkUserTokenBalanceV3(user1);
        assertEq(daiAToken.balanceOf(user1), 100 ether);
    }

    function testWithdraw() public {
        vm.startPrank(user1);
        faucet(address(dai), user1, 100 ether);
        lendingPoolV3.deposit(address(dai), 100 ether, user1, uint16(0));
        lendingPoolV3.withdraw(address(dai), 50 ether, user1);
        vm.stopPrank();
        sinkUserTokenBalanceV3(user1);
        assertEq(daiAToken.balanceOf(user1), 50 ether);
    }

    function testBorrow() public {
        faucetWeth(address(lendingPoolV3), 100000 ether);
        faucet(address(dai), user1, 2000 ether);
        vm.startPrank(user1);
        lendingPoolV3.deposit(address(dai), 2000 ether, user1, uint16(0));
        lendingPoolV3.borrow(address(weth), 7 * 1e17, user1);
        vm.stopPrank();
        sinkUserTokenBalanceV3(user1);
        assertEq(wethDebtToken.balanceOf(user1), 7 * 1e17);
    }

    function testRepay() public {
        faucetWeth(address(lendingPoolV3), 100000 ether);
        faucet(address(dai), user1, 2000 * 100 ether);
        vm.startPrank(user1);
        lendingPoolV3.deposit(address(dai), 2000 * 100 ether, user1, uint16(0));
        lendingPoolV3.borrow(address(weth), 79 ether, user1);
        lendingPoolV3.repay(address(weth), 40 ether, 1, user1);
        vm.stopPrank();
        sinkUserTokenBalanceV3(user1);
        assertEq(wethDebtToken.balanceOf(user1), 39 ether);
    }

    function testLiquidationCall() public {
        faucetWeth(address(lendingPoolV3), 100000 ether);
        faucet(address(dai), address(lendingPoolV3), 100000 * 2000 ether);
        faucetWeth(address(user2), 100 ether);

        vm.startPrank(user1);
        faucet(address(dai), user1, 200 * 2000 ether);
        lendingPoolV3.deposit(address(dai), 200 * 2000 ether, user1, uint16(0));
        lendingPoolV3.borrow(address(weth), 159 ether, user1);
        MockERC20(daiAToken).burn(user1, 2000 * 2 ether);
        vm.stopPrank();

        vm.startPrank(user2);
        lendingPoolV3.liquidationCall(address(weth), address(wethDebtToken), user1, 50 ether, true);
        vm.stopPrank();

        sinkUserTokenBalanceV3(user1);
        sinkUserTokenBalanceV3(user2);

        assertEq(wethDebtToken.balanceOf(user1), 109 ether);
    }
}
