/*

    Copyright 2023 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0*/

pragma solidity 0.8.15;

import "../Context.t.sol";

contract MarginTradingFactoryTest is Context {
    function setUp() public {
        contextBasic();
        approveAllToken();
    }

    function testGetCreateMarginTradingAddressh() public view {
        address u1mt = marginTradingFactory.getCreateMarginTradingAddress(1, 1, user1);
        console2.log("u1mt = ", u1mt);
        address u2mt = marginTradingFactory.getCreateMarginTradingAddress(1, 1, user2);
        console2.log("u2mt = ", u2mt);
    }

    function testGetUserMarginTradingNum() public {
        (uint256 _crossNum, uint256 _isolateNum) = marginTradingFactory.getUserMarginTradingNum(user1);
        assertEq(_crossNum, 0);
        assertEq(_isolateNum, 0);
    }

    //deposit 100 DAI borrow 1eth
    function testCreateMarginTradingOne() public {
        openMarginTradingDAI(user1);
    }

    //deposit 1weth  borrow 100 DAI
    function testCreateMarginTradingTwo() public {
        address _depositToken = address(weth);
        address _borrowToken = address(dai);

        faucet(address(depositToken), user1, 10000 ether);
        faucetWeth(user1, 10000 ether);
        faucet(address(_borrowToken), address(lendingPool), 10000 ether);
        faucetWeth(address(lendingPool), 10000 ether);
        setLendingPoolToken(MockERC20(address(weth)), dai);

        uint256 depositAmt = 1 ether;
        uint256 borrowAmt = 100 ether;
        // 先预测地址
        vm.startPrank(user1);
        (, uint256 _isolateNum) = marginTradingFactory.getUserMarginTradingNum(user1);
        address marginTradingAddress = marginTradingFactory.getCreateMarginTradingAddress(_isolateNum, 2, user1);
        // 组装存款参数
        bytes memory depositParams = encodeDepositParams(1, address(_depositToken), depositAmt);
        // 组装 swap参数
        bytes memory swapParams = getSwapCalldata(address(_borrowToken), address(_depositToken), borrowAmt);
        uint256 swapOutAmt = getRouterToAmount(address(_borrowToken), address(_depositToken), borrowAmt);
        bytes memory executeParams;
        //组装执行参数
        {
            address[] memory _withdrawAssets = new address[](1);
            uint256[] memory _withdrawAmounts = new uint256[](1);
            uint256[] memory _rateMode = new uint256[](1);
            address[] memory _debtTokens = new address[](1);
            address[] memory _swapApproveToken = new address[](1);
            _swapApproveToken[0] = address(_borrowToken);
            address[] memory _tradeAssets = new address[](1);
            _tradeAssets[0] = address(_depositToken);
            executeParams = encodeExecuteParams(
                1,
                address(router),
                address(dodoApprove),
                _swapApproveToken,
                swapParams,
                _tradeAssets,
                _withdrawAssets,
                _withdrawAmounts,
                _rateMode,
                _debtTokens
            );
        }

        //组装flashloand 参数
        bytes memory flashLoanParams;
        {
            address[] memory _assets = new address[](1);
            _assets[0] = address(_borrowToken);
            uint256[] memory _amounts = new uint256[](1);
            _amounts[0] = borrowAmt;
            uint256[] memory _modes = new uint256[](1);
            _modes[0] = 1;
            address _mainToken = address(_borrowToken);
            flashLoanParams = encodeFlashLoan(_assets, _amounts, _modes, _mainToken, executeParams);
        }
        //执行
        marginTradingFactory.createMarginTrading(2, depositParams, flashLoanParams);
        vm.stopPrank();
        sinkUserTokenBalance(marginTradingAddress);
        assertEq(aToken.balanceOf(marginTradingAddress), depositAmt + swapOutAmt);
        assertEq(debtToken.balanceOf(marginTradingAddress), borrowAmt);
    }

    //deposit 1eth  borrow 100 DAI
    function testCreateMarginTradingThree() public {
        address _depositToken = address(weth);
        address _borrowToken = address(dai);

        faucet(address(depositToken), user1, 10000 ether);
        vm.deal(user1, 100 ether);
        faucet(address(_borrowToken), address(lendingPool), 10000 ether);
        faucetWeth(address(lendingPool), 10000 ether);
        setLendingPoolToken(MockERC20(address(weth)), dai);

        uint256 depositAmt = 1 ether;
        uint256 borrowAmt = 100 ether;
        // 先预测地址
        vm.startPrank(user1);
        (, uint256 _isolateNum) = marginTradingFactory.getUserMarginTradingNum(user1);
        address marginTradingAddress = marginTradingFactory.getCreateMarginTradingAddress(_isolateNum, 2, user1);
        // 组装存款参数 deposit eth
        bytes memory depositParams = encodeDepositParams(2, address(0), 0);
        // 组装 swap参数
        bytes memory swapParams = getSwapCalldata(address(_borrowToken), address(_depositToken), borrowAmt);
        uint256 swapOutAmt = getRouterToAmount(address(_borrowToken), address(_depositToken), borrowAmt);
        bytes memory executeParams;
        //组装执行参数
        {
            address[] memory _withdrawAssets = new address[](1);
            uint256[] memory _withdrawAmounts = new uint256[](1);
            uint256[] memory _rateMode = new uint256[](1);
            address[] memory _debtTokens = new address[](1);
            address[] memory _swapApproveToken = new address[](1);
            _swapApproveToken[0] = address(_borrowToken);
            address[] memory _tradeAssets = new address[](1);
            _tradeAssets[0] = address(_depositToken);
            executeParams = encodeExecuteParams(
                1,
                address(router),
                address(dodoApprove),
                _swapApproveToken,
                swapParams,
                _tradeAssets,
                _withdrawAssets,
                _withdrawAmounts,
                _rateMode,
                _debtTokens
            );
        }

        //组装flashloand 参数
        bytes memory flashLoanParams;
        {
            address[] memory _assets = new address[](1);
            _assets[0] = address(_borrowToken);
            uint256[] memory _amounts = new uint256[](1);
            _amounts[0] = borrowAmt;
            uint256[] memory _modes = new uint256[](1);
            _modes[0] = 1;
            address _mainToken = address(_borrowToken);
            flashLoanParams = encodeFlashLoan(_assets, _amounts, _modes, _mainToken, executeParams);
        }
        //执行
        marginTradingFactory.createMarginTrading{value: depositAmt}(2, depositParams, flashLoanParams);
        vm.stopPrank();
        sinkUserTokenBalance(marginTradingAddress);
        assertEq(aToken.balanceOf(marginTradingAddress), depositAmt + swapOutAmt);
        assertEq(debtToken.balanceOf(marginTradingAddress), borrowAmt);
    }

    //deposit 100DAI
    function testCreateMarginTradingFour() public {
        faucet(address(dai), user1, 10000 ether);

        uint256 depositAmt = 100 ether;
        // 先预测地址
        vm.startPrank(user1);
        (, uint256 _isolateNum) = marginTradingFactory.getUserMarginTradingNum(user1);
        address marginTradingAddress = marginTradingFactory.getCreateMarginTradingAddress(_isolateNum, 2, user1);
        // 组装存款参数
        bytes memory depositParams = encodeDepositParams(1, address(dai), depositAmt);

        //组装flashloand 参数
        bytes memory flashLoanParams = new bytes(0);

        //执行
        marginTradingFactory.createMarginTrading(2, depositParams, flashLoanParams);
        vm.stopPrank();
        sinkUserTokenBalance(marginTradingAddress);
        assertEq(dai.balanceOf(marginTradingAddress), depositAmt);
    }

    //deposit 1eth
    function testCreateMarginTradingFive() public {
        vm.deal(user1, 100 ether);
        uint256 depositAmt = 1 ether;
        // 先预测地址
        vm.startPrank(user1);
        (, uint256 _isolateNum) = marginTradingFactory.getUserMarginTradingNum(user1);
        address marginTradingAddress = marginTradingFactory.getCreateMarginTradingAddress(_isolateNum, 2, user1);
        // 组装存款参数 deposit eth
        bytes memory depositParams = encodeDepositParams(2, address(0), 0);

        //组装flashloand 参数
        bytes memory flashLoanParams = new bytes(0);

        //执行
        marginTradingFactory.createMarginTrading{value: depositAmt}(2, depositParams, flashLoanParams);
        vm.stopPrank();
        sinkUserTokenBalance(marginTradingAddress);
        assertEq(weth.balanceOf(marginTradingAddress), depositAmt);
    }

    function testCreateMarginTradingSix() public {
        vm.deal(user1, 100 ether);
        uint256 depositAmt = 1 ether;
        // 先预测地址
        vm.startPrank(user1);
        (, uint256 _isolateNum) = marginTradingFactory.getUserMarginTradingNum(user1);
        address marginTradingAddress = marginTradingFactory.getCreateMarginTradingAddress(_isolateNum, 2, user1);
        // 组装存款参数 deposit eth
        bytes memory depositParams = encodeDepositParams(2, address(0), 0);

        //组装flashloand 参数
        bytes memory flashLoanParams = new bytes(0);
        vm.stopPrank();
        vm.prank(user2);
        vm.expectRevert();
        //执行
        marginTradingFactory.createMarginTrading{value: depositAmt}(2, depositParams, flashLoanParams);

        sinkUserTokenBalance(marginTradingAddress);
        assertEq(weth.balanceOf(marginTradingAddress), 0);
    }

    function testCreateMarginTradingSeven() public {
        vm.deal(user1, 100 ether);
        uint256 depositAmt = 1 ether;
        // 先预测地址
        vm.startPrank(user1);
        (, uint256 _isolateNum) = marginTradingFactory.getUserMarginTradingNum(user1);
        address marginTradingAddress = marginTradingFactory.getCreateMarginTradingAddress(_isolateNum, 2, user1);
        // 组装存款参数 deposit eth
        bytes memory depositParams = encodeDepositParams(2, address(0), 0);

        //组装flashloand 参数
        bytes memory flashLoanParams = new bytes(0);

        //执行
        marginTradingFactory.createMarginTrading{value: depositAmt}(2, depositParams, flashLoanParams);
        marginTradingFactory.createMarginTrading{value: depositAmt}(2, depositParams, flashLoanParams);
        vm.stopPrank();
        (, uint256 _isolateNum2) = marginTradingFactory.getUserMarginTradingNum(user1);
        sinkUserTokenBalance(marginTradingAddress);
        assertEq(_isolateNum2, 2);
    }

    

    // function testSendMarginTradingETH() public {
    //     openMarginTradingDAI(user1);
    //     address marginTradingAddress = marginTradingFactory.getCreateMarginTradingAddress(0, 2, user1);
    //     vm.deal(marginTradingAddress, 10000 ether);
    //     vm.prank(marginCreator);
    //     marginTradingFactory.sendMarginTradingETH(marginTradingAddress, user1, 10000 ether);
    //     assertEq(user1.balance, 10000 ether);
    // }

    // function testSendMarginTradingERC20() public {
    //     openMarginTradingDAI(user1);
    //     address marginTradingAddress = marginTradingFactory.getCreateMarginTradingAddress(0, 2, user1);
    //     faucet(address(dai), marginTradingAddress, 10000 ether);
    //     // console2.log("dai before",dai.balanceOf(user1) / 1e18);
    //     vm.prank(marginCreator);
    //     marginTradingFactory.sendMarginTradingERC20(marginTradingAddress, address(dai), user1, 10000 ether);
    //     // console2.log("dai after",dai.balanceOf(user1) / 1e18);
    //     assertEq(dai.balanceOf(user1), 10000 ether);
    // }

    function testCleanToken() public {
        faucet(address(dai), address(marginTradingFactory), 10000 ether);
        vm.prank(marginCreator);
        marginTradingFactory.cleanToken(address(dai), user1, 10000 ether);
        // console2.log("dai after",dai.balanceOf(user1) / 1e18);
        assertEq(dai.balanceOf(user1), 10000 ether);
    }

    function testCleanTokenTwo() public {
        faucet(address(dai), address(marginTradingFactory), 10000 ether);
        vm.prank(marginCreator);
        marginTradingFactory.transferOwnership(user2);
        vm.prank(user1);
        vm.expectRevert();
        marginTradingFactory.cleanToken(address(dai), user1, 10000 ether);
        // console2.log("dai after",dai.balanceOf(user1) / 1e18);
        assertEq(dai.balanceOf(user1), 0 ether);
    }

    function testCleanETH() public {
        vm.deal(address(marginTradingFactory), 10000 ether);
        vm.prank(marginCreator);
        marginTradingFactory.cleanETH(user1, 10000 ether);
        // console2.log("dai after",dai.balanceOf(user1) / 1e18);
        assertEq(user1.balance, 10000 ether);
    }

    function testCleanETHTwo() public {
        vm.deal(address(marginTradingFactory), 10000 ether);
        vm.prank(marginCreator);
        marginTradingFactory.transferOwnership(user2);
        vm.prank(user1);
        vm.expectRevert();
        marginTradingFactory.cleanETH(user1, 10000 ether);
        // console2.log("dai after",dai.balanceOf(user1) / 1e18);
        assertEq(user1.balance, 0 ether);
    }

    function testAddFlashLoanProxy() public {
        openMarginTradingDAI(user1);
        address marginTradingAddress = marginTradingFactory.getCreateMarginTradingAddress(0, 2, user1);
        vm.prank(user1);
        marginTradingFactory.addFlashLoanProxy(marginTradingAddress, user2);
        assertEq(marginTradingFactory.isAllowedProxy(marginTradingAddress, user2), true);
    }

    function testAddFlashLoanProxyTwo() public {
        openMarginTradingDAI(user1);
        address marginTradingAddress = marginTradingFactory.getCreateMarginTradingAddress(0, 2, user1);
        vm.prank(user2);
        vm.expectRevert();
        marginTradingFactory.addFlashLoanProxy(marginTradingAddress, user3);
        assertEq(marginTradingFactory.isAllowedProxy(marginTradingAddress, user3), false);
    }

    function testRemoveFlashLoanProxy() public {
        openMarginTradingDAI(user1);
        address marginTradingAddress = marginTradingFactory.getCreateMarginTradingAddress(0, 2, user1);
        vm.prank(user1);
        marginTradingFactory.addFlashLoanProxy(marginTradingAddress, user2);
        vm.prank(user1);
        marginTradingFactory.removeFlashLoanProxy(marginTradingAddress, user2);
        assertEq(marginTradingFactory.isAllowedProxy(marginTradingAddress, user2), false);
    }

    function testRemoveFlashLoanProxyTwo() public {
        openMarginTradingDAI(user1);
        address marginTradingAddress = marginTradingFactory.getCreateMarginTradingAddress(0, 2, user1);
        vm.prank(user1);
        marginTradingFactory.addFlashLoanProxy(marginTradingAddress, user2);
        vm.prank(user3);
        vm.expectRevert();
        marginTradingFactory.removeFlashLoanProxy(marginTradingAddress, user2);
        assertEq(marginTradingFactory.isAllowedProxy(marginTradingAddress, user2), true);
    }

    function testDepositMarginTradingERC20() public {
        openMarginTradingDAI(user1);
        address marginTradingAddress = marginTradingFactory.getCreateMarginTradingAddress(0, 2, user1);
        uint256 beforeBalance = aToken.balanceOf(marginTradingAddress);
        faucet(address(dai), user1, 100 ether);
        vm.prank(user1);
        marginTradingFactory.depositMarginTradingERC20(marginTradingAddress, address(dai), 100 ether, true, uint8(2));
        assertEq(aToken.balanceOf(marginTradingAddress), beforeBalance + 100 ether);
    }

    function testDepositMarginTradingETH() public {
        openMarginTradingDAI(user1);
        address marginTradingAddress = marginTradingFactory.getCreateMarginTradingAddress(0, 2, user1);
        setLendingPoolToken(MockERC20(address(weth)), dai);
        uint256 beforeBalance = aToken.balanceOf(marginTradingAddress);
        vm.deal(user1, 100 ether);
        vm.prank(user1);
        marginTradingFactory.depositMarginTradingETH{value: 100 ether}(marginTradingAddress, true, uint8(2));
        assertEq(aToken.balanceOf(marginTradingAddress), beforeBalance + 100 ether);
    }

    function testDepositMarginTradingETHTwo() public {
        openMarginTradingDAI(user1);
        address marginTradingAddress = marginTradingFactory.getCreateMarginTradingAddress(0, 2, user1);
        setLendingPoolToken(MockERC20(address(weth)), dai);
        uint256 beforeBalance = aToken.balanceOf(marginTradingAddress);
        vm.deal(user1, 100 ether);
        vm.prank(user2);
        vm.expectRevert();
        marginTradingFactory.depositMarginTradingETH{value: 100 ether}(marginTradingAddress, true, uint8(2));
        assertEq(aToken.balanceOf(marginTradingAddress), beforeBalance);
    }

    function testWithdrawERC20() public {
        openMarginTradingDAI(user1);
        address marginTradingAddress = marginTradingFactory.getCreateMarginTradingAddress(0, 2, user1);
        uint256 beforeBalance = aToken.balanceOf(marginTradingAddress);
        approveTokenTarget(address(aToken), address(lendingPool), marginTradingAddress);
        vm.prank(address(user1));
        IMarginTrading(marginTradingAddress).withdrawERC20(address(dai), 100 ether, true, 2);
        assertEq(aToken.balanceOf(marginTradingAddress), beforeBalance - 100 ether);
    }

    function testWithdrawETH() public {
        openMarginTradingWeth(user1);
        address marginTradingAddress = marginTradingFactory.getCreateMarginTradingAddress(0, 2, user1);
        approveTokenTarget(address(aToken), address(lendingPool), marginTradingAddress);
        console2.log("lendingPool.weth.balance ", weth.balanceOf(address(lendingPool)));
        console2.log("weth.balance ", address(weth).balance);
        console2.log("aToken.balance ", aToken.balanceOf(address(marginTradingAddress)));
        uint256 beforeBalance = user1.balance;
        vm.prank(user1);
        IMarginTrading(marginTradingAddress).withdrawETH(true, 10 ether, uint8(2));
        assertEq(user1.balance, beforeBalance + 10 ether);
    }

    // function testCreateMarginTradingEight() public {
    //     faucet(address(depositToken), user1, 1000 ether);
    //     faucetWeth(address(lendingPool), 10000 ether);
    //     uint256 depositAmt = 100 ether;
    //     uint256 borrowAmt = 1 ether;
    //     // 先预测地址
    //     vm.startPrank(user1);
    //     (, uint256 _isolateNum) = marginTradingFactory.getUserMarginTradingNum(user1);
    //     address marginTradingAddress = marginTradingFactory.getCreateMarginTradingAddress(_isolateNum, 2, user1);
    //     // 组装存款参数
    //     bytes memory depositParams = encodeDepositParams(1, address(depositToken), depositAmt);
    //     // 组装 swap参数
    //     bytes memory swapParams = getSwapCalldata(address(borrowToken), address(depositToken), borrowAmt);
    //     uint256 swapOutAmt = getRouterToAmount(address(borrowToken), address(depositToken), borrowAmt);
    //     bytes memory executeParams;
    //     //组装执行参数
    //     {
    //         address[] memory _withdrawAssets = new address[](1);
    //         uint256[] memory _withdrawAmounts = new uint256[](1);
    //         uint256[] memory _rateMode = new uint256[](1);
    //         address[] memory _debtTokens = new address[](1);
    //         address[] memory _swapApproveToken = new address[](1);
    //         _swapApproveToken[0] = address(borrowToken);
    //         address[] memory _tradeAssets = new address[](1);
    //         _tradeAssets[0] = address(depositToken);
    //         executeParams = encodeExecuteParams(
    //             1,
    //             address(router),
    //             address(dodoApprove),
    //             _swapApproveToken,
    //             swapParams,
    //             _tradeAssets,
    //             _withdrawAssets,
    //             _withdrawAmounts,
    //             _rateMode,
    //             _debtTokens
    //         );
    //     }

    //     //组装flashloand 参数
    //     bytes memory flashLoanParams;
    //     {
    //         address[] memory _assets = new address[](1);
    //         _assets[0] = address(borrowToken);
    //         uint256[] memory _amounts = new uint256[](1);
    //         _amounts[0] = borrowAmt;
    //         uint256[] memory _modes = new uint256[](1);
    //         _modes[0] = 1;
    //         address _mainToken = address(borrowToken);
    //         flashLoanParams = encodeFlashLoan(_assets, _amounts, _modes, _mainToken, executeParams);
    //     }
    //     //执行
    //     marginTradingFactory.createMarginTrading(2, depositParams, flashLoanParams);
    //     vm.expectRevert();
    //     marginTradingFactory.createMarginTrading(2, depositParams, flashLoanParams);
    //     vm.stopPrank();
    //     sinkUserTokenBalance(marginTradingAddress);
    //     console2.log("------------ +1 --------");
    //     sinkUserTokenBalance(marginTradingFactory.getCreateMarginTradingAddress(_isolateNum + 1, 2, user1));
    //     assertEq(_isolateNum, 1);
    // }
}
