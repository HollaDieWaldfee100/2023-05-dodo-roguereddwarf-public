/*

    Copyright 2023 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0*/

pragma solidity 0.8.15;

import "../Context.t.sol";

contract MockRouterlTest is Context {
    function setUp() public {
        contextBasic();
        approveAllToken();
    }

    function testSwap() public {
        faucet(address(depositToken), user1, 10000 ether);
        vm.startPrank(user1);
        uint256 toAmount = getRouterToAmount(address(depositToken), address(borrowToken), 10000 ether);
        console2.log("toAmount:", toAmount);
        router.swap(address(depositToken), address(borrowToken), 10000 ether);
        vm.stopPrank();
        assertEq(borrowToken.balanceOf(user1), toAmount);
    }

    function testGetRpiterToAmount() public {
        uint256 swapOutAmt = getRouterToAmount(address(depositToken), address(borrowToken), 1 ether);
        sinkUserTokenBalance(address(router));
        console2.log("swapOutAmt :", swapOutAmt);
    }
}
