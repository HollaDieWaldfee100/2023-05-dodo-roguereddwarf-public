/*

    Copyright 2023 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0*/

pragma solidity 0.8.15;

import "../Context.t.sol";

contract MarginTradingTest is Context {
    function setUp() public {
        contextBasicV2();
        approveAllTokenV2();
    }

    //deposit 100 DAI borrow 1eth
    function testExecuteFlashLoansOpen() public {
        faucet(address(dai), user1, 100 ether);
        faucetWeth(address(lendingPoolV2), 10000 ether);
        uint256 depositAmt = 100 ether;
        uint256 borrowAmt = 1 ether;
        vm.startPrank(user1);
        address _marginTrading = createMarginTradingContract();
        // 组装 swap参数
        bytes memory swapParams = getSwapCalldata(address(weth), address(dai), borrowAmt);
        bytes memory executeParams;
        //组装执行参数
        {
            address[] memory _withdrawAssets = new address[](1);
            uint256[] memory _withdrawAmounts = new uint256[](1);
            uint256[] memory _rateMode = new uint256[](1);
            address[] memory _debtTokens = new address[](1);
            address[] memory _swapApproveToken = new address[](1);
            _swapApproveToken[0] = address(weth);
            address[] memory _tradeAssets = new address[](1);
            _tradeAssets[0] = address(dai);
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
        address[] memory _assets = new address[](1);
        _assets[0] = address(weth);
        uint256[] memory _amounts = new uint256[](1);
        _amounts[0] = borrowAmt;
        uint256[] memory _modes = new uint256[](1);
        _modes[0] = 1;
        address _mainToken = address(weth);
        // 先存款
        marginTradingFactory.depositMarginTradingERC20(_marginTrading, address(dai), depositAmt, true, 1);
        //再执行
        //sinkUserTokenBalanceV2(_marginTrading);
        IMarginTrading(_marginTrading).executeFlashLoans(_assets, _amounts, _modes, _mainToken, executeParams);
        vm.stopPrank();
        sinkUserTokenBalanceV2(_marginTrading);
        assertEq(wethDebtToken.balanceOf(_marginTrading), 1 ether);

        //vm.warp(300 days);
        //console.log(wethDebtToken.balanceOf(_marginTrading));
    }

    //deposit 100 DAI borrow 10eth => repay eth
    function testExecuteFlashLoansClose1() public {
        address _marginTrading = openMarginTradingDAIV2(user1, address(dai), address(weth), 10000 ether, 10 ether);
        // sinkUserTokenBalanceV2(_marginTrading);

        //-------------------------- close -----------------------------------//

        uint256 borrowAmt = 500 ether;
        // 组装 swap参数
        bytes memory swapParams = getSwapCalldata(address(dai), address(weth), borrowAmt);
        uint256 swapOutAmt = getRouterToAmount(address(dai), address(weth), borrowAmt);
        //组装执行参数
        bytes memory executeParams;
        {
            address[] memory _withdrawAssets = new address[](1);
            _withdrawAssets[0] = address(dai);
            uint256[] memory _withdrawAmounts = new uint256[](1);
            _withdrawAmounts[0] = (borrowAmt * 10009) / 10000;
            console.log(_withdrawAmounts[0]);
            uint256[] memory _rateMode = new uint256[](1);
            _rateMode[0] = 0;
            address[] memory _debtTokens = new address[](1);
            _debtTokens[0] = address(wethDebtToken);
            address[] memory _swapApproveToken = new address[](1);
            _swapApproveToken[0] = address(dai);
            address[] memory _tradeAssets = new address[](1);
            _tradeAssets[0] = address(weth);
            executeParams = encodeExecuteParams(
                0, // repay
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
        address[] memory _assets = new address[](1);
        uint256[] memory _amounts = new uint256[](1);
        uint256[] memory _modes = new uint256[](1);
        _assets[0] = address(dai);
        _amounts[0] = borrowAmt;
        _modes[0] = 0;
        uint256 beforeDebtBalance = wethDebtToken.balanceOf(_marginTrading);
        vm.startPrank(user1);
        //执行 close
        console.log(wethDebtToken.balanceOf(_marginTrading));
        // faucet(_marginTrading, user1, 100 ether);
        IMarginTrading(_marginTrading).executeFlashLoans(_assets, _amounts, _modes, address(weth), executeParams);
        vm.stopPrank();
        sinkUserTokenBalanceV2(_marginTrading);
        assertEq(wethDebtToken.balanceOf(_marginTrading), beforeDebtBalance - swapOutAmt);
        console.log(wethDebtToken.balanceOf(_marginTrading));
    }

    function testExecuteFlashLoansCloseAttack() public {
        address _marginTrading = openMarginTradingDAIV2(user1, address(dai), address(weth), 10000 ether, 10 ether);
        // sinkUserTokenBalanceV2(_marginTrading);

        //-------------------------- close -----------------------------------//

        uint256 borrowAmt = 500 ether;
        // 组装 swap参数
        bytes memory swapParams = getSwapCalldata(address(dai), address(weth), borrowAmt);
        uint256 swapOutAmt = getRouterToAmount(address(dai), address(weth), borrowAmt);
        //组装执行参数
        bytes memory executeParams;
        {
            address[] memory _withdrawAssets = new address[](1);
            _withdrawAssets[0] = address(dai);
            uint256[] memory _withdrawAmounts = new uint256[](1);
            _withdrawAmounts[0] = (borrowAmt * 10009) / 10000;
            console.log(_withdrawAmounts[0]);
            uint256[] memory _rateMode = new uint256[](1);
            _rateMode[0] = 0;
            address[] memory _debtTokens = new address[](1);
            _debtTokens[0] = address(wethDebtToken);
            address[] memory _swapApproveToken = new address[](1);
            _swapApproveToken[0] = address(dai);
            address[] memory _tradeAssets = new address[](1);
            _tradeAssets[0] = address(weth);
            executeParams = encodeExecuteParams(
                0, // repay
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
        address[] memory _assets = new address[](1);
        uint256[] memory _amounts = new uint256[](1);
        uint256[] memory _modes = new uint256[](1);
        _assets[0] = address(dai);
        _amounts[0] = borrowAmt;
        _modes[0] = 0;
        uint256 beforeDebtBalance = wethDebtToken.balanceOf(_marginTrading);
        vm.startPrank(user1);
        //执行 close
        console.log(wethDebtToken.balanceOf(_marginTrading));
        lendingPoolV2.flashLoan(address(_marginTrading),_assets,_amounts,_modes,user1,executeParams,0);
        // IMarginTrading(_marginTrading).executeFlashLoans(_assets, _amounts, _modes, address(weth), executeParams);
        vm.stopPrank();
        // sinkUserTokenBalanceV2(_marginTrading);
        // assertEq(wethDebtToken.balanceOf(_marginTrading), beforeDebtBalance - swapOutAmt);
        // console.log(wethDebtToken.balanceOf(_marginTrading));
    }

    //deposit 100 DAI borrow 10eth => repay eth
    function testExecuteFlashLoansCloseTwo() public {
        address _marginTrading = openMarginTradingDAIV2(user1, address(dai), address(weth), 10000 ether, 10 ether);

        //-------------------------- close -----------------------------------//

        uint256 borrowAmt = 500 ether;
        // 组装 swap参数
        bytes memory swapParams = getSwapCalldata(address(dai), address(weth), borrowAmt);
        uint256 swapOutAmt = getRouterToAmount(address(dai), address(weth), borrowAmt);
        //组装执行参数
        bytes memory executeParams;
        {
            address[] memory _withdrawAssets = new address[](1);
            _withdrawAssets[0] = address(dai);
            uint256[] memory _withdrawAmounts = new uint256[](1);
            _withdrawAmounts[0] = (borrowAmt * 10009) / 10000;
            uint256[] memory _rateMode = new uint256[](1);
            _rateMode[0] = 0;
            address[] memory _debtTokens = new address[](1);
            _debtTokens[0] = address(wethDebtToken);
            address[] memory _swapApproveToken = new address[](1);
            _swapApproveToken[0] = address(dai);
            address[] memory _tradeAssets = new address[](1);
            _tradeAssets[0] = address(weth);
            executeParams = encodeExecuteParams(
                0,
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
        address[] memory _assets = new address[](1);
        uint256[] memory _amounts = new uint256[](1);
        uint256[] memory _modes = new uint256[](1);
        _assets[0] = address(dai);
        _amounts[0] = borrowAmt;
        _modes[0] = 0;
        uint256 beforeDebtBalance = wethDebtToken.balanceOf(_marginTrading);
        vm.startPrank(user2);
        //执行 close
        vm.expectRevert();
        IMarginTrading(_marginTrading).executeFlashLoans(_assets, _amounts, _modes, address(weth), executeParams);
        vm.stopPrank();
        sinkUserTokenBalanceV2(_marginTrading);
        assertEq(wethDebtToken.balanceOf(_marginTrading), beforeDebtBalance);
    }

    //deposit 100 DAI borrow 10eth => repay eth
    function testExecuteFlashLoansAllCloseWithdreawEth() public {
        address _marginTrading = openMarginTradingDAIV2(user1, address(dai), address(weth), 10000 ether, 10 ether);

        //-------------------------- close -----------------------------------//
        uint256 user1EthBalanceBefore = user1.balance;

        uint256 borrowAmt = daiAToken.balanceOf(_marginTrading);
        // uint256 borrowAmt = 500 ether;
        // 组装 swap参数
        bytes memory swapParams = getSwapCalldata(address(dai), address(weth), (borrowAmt * 10000) / 10009);
        uint256 swapOutAmt = getRouterToAmount(address(dai), address(weth), (borrowAmt * 10000) / 10009);
        uint256 debtTokenBalance = wethDebtToken.balanceOf(_marginTrading);
        //组装执行参数
        bytes memory executeParams;
        {
            address[] memory _withdrawAssets = new address[](1);
            _withdrawAssets[0] = address(dai);
            uint256[] memory _withdrawAmounts = new uint256[](1);
            _withdrawAmounts[0] = borrowAmt;
            uint256[] memory _rateMode = new uint256[](1);
            _rateMode[0] = 0;
            address[] memory _debtTokens = new address[](1);
            _debtTokens[0] = address(wethDebtToken);
            address[] memory _swapApproveToken = new address[](1);
            _swapApproveToken[0] = address(dai);
            address[] memory _tradeAssets = new address[](1);
            _tradeAssets[0] = address(weth);
            executeParams = encodeExecuteParams(
                2,
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
        address[] memory _assets = new address[](1);
        uint256[] memory _amounts = new uint256[](1);
        uint256[] memory _modes = new uint256[](1);
        _assets[0] = address(dai);
        _amounts[0] = (borrowAmt * 10000) / 10009;
        _modes[0] = 0;
        // uint256 beforeDebtBalance = wethDebtToken.balanceOf(_marginTrading);
        vm.startPrank(user1);
        //执行 close
        IMarginTrading(_marginTrading).executeFlashLoans(_assets, _amounts, _modes, address(weth), executeParams);
        vm.stopPrank();
        sinkUserTokenBalanceV2(_marginTrading);
        assertEq(user1EthBalanceBefore + swapOutAmt - debtTokenBalance, user1.balance);
    }

    //deposit 100 DAI borrow 10eth => repay eth
    function testExecuteFlashLoansAllClose() public {
        address _marginTrading = openMarginTradingDAIV2(user1, address(dai), address(weth), 10000 ether, 1 ether);

        //-------------------------- close -----------------------------------//

        uint256 borrowAmt = 2000 ether;
        // 组装 swap参数
        bytes memory swapParams = getSwapCalldata(address(dai), address(weth), borrowAmt);
        uint256 swapOutAmt = getRouterToAmount(address(dai), address(weth), borrowAmt);
        //组装执行参数
        bytes memory executeParams;
        {
            address[] memory _withdrawAssets = new address[](1);
            _withdrawAssets[0] = address(dai);
            uint256[] memory _withdrawAmounts = new uint256[](1);
            _withdrawAmounts[0] = (borrowAmt * 10009) / 10000;
            uint256[] memory _rateMode = new uint256[](1);
            _rateMode[0] = 0;
            address[] memory _debtTokens = new address[](1);
            _debtTokens[0] = address(wethDebtToken);
            address[] memory _swapApproveToken = new address[](1);
            _swapApproveToken[0] = address(dai);
            address[] memory _tradeAssets = new address[](1);
            _tradeAssets[0] = address(weth);
            executeParams = encodeExecuteParams(
                2,
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
        address[] memory _assets = new address[](1);
        uint256[] memory _amounts = new uint256[](1);
        uint256[] memory _modes = new uint256[](1);
        _assets[0] = address(dai);
        _amounts[0] = borrowAmt;
        _modes[0] = 0;
        uint256 beforeDebtBalance = wethDebtToken.balanceOf(_marginTrading);
        vm.startPrank(user1);
        //执行 close
        IMarginTrading(_marginTrading).executeFlashLoans(_assets, _amounts, _modes, address(weth), executeParams);
        vm.stopPrank();
        sinkUserTokenBalanceV2(_marginTrading);
        assertEq(wethDebtToken.balanceOf(_marginTrading), 0);
    }

    function testLendingPoolWithdraw() public {
        address _marginTrading = openMarginTradingDAIV2(user1, address(dai), address(weth), 10000 ether, 1 ether);
        uint256 beforeBalance = dai.balanceOf(user1);
        vm.startPrank(user1);
        //执行 close
        IMarginTrading(_marginTrading).withdrawERC20(address(dai), 100 ether, true, 2);
        vm.stopPrank();
        sinkUserTokenBalanceV2(_marginTrading);
        assertEq(dai.balanceOf(user1), beforeBalance + 100 ether);
    }

    function testLendingPoolDeposit() public {
        address _marginTrading = openMarginTradingDAIV2(user1, address(dai), address(weth), 10000 ether, 1 ether);
        uint256 beforeBalance = daiAToken.balanceOf(_marginTrading);
        faucet(address(dai), user1, 100 ether);

        vm.startPrank(user1);
        //执行 存款
        marginTradingFactory.depositMarginTradingERC20(_marginTrading, address(dai), 100 ether, true, uint8(2));
        vm.stopPrank();
        sinkUserTokenBalanceV2(_marginTrading);
        assertEq(daiAToken.balanceOf(_marginTrading), beforeBalance + 100 ether);
    }

    //deposit 100 DAI borrow 10eth => repay eth
    function testProxyExecuteFlashLoansClose() public {
        address _marginTrading = openMarginTradingDAIV2(user1, address(dai), address(weth), 10000 ether, 10 ether);

        //-------------------------- close -----------------------------------//

        vm.prank(user1);
        marginTradingFactory.addFlashLoanProxy(_marginTrading, user2);

        uint256 borrowAmt = 500 ether;
        // 组装 swap参数
        bytes memory swapParams = getSwapCalldata(address(dai), address(weth), borrowAmt);
        uint256 swapOutAmt = getRouterToAmount(address(dai), address(weth), borrowAmt);
        //组装执行参数
        bytes memory executeParams;
        {
            address[] memory _withdrawAssets = new address[](1);
            _withdrawAssets[0] = address(dai);
            uint256[] memory _withdrawAmounts = new uint256[](1);
            _withdrawAmounts[0] = (borrowAmt * 10009) / 10000;
            uint256[] memory _rateMode = new uint256[](1);
            _rateMode[0] = 0;
            address[] memory _debtTokens = new address[](1);
            _debtTokens[0] = address(wethDebtToken);
            address[] memory _swapApproveToken = new address[](1);
            _swapApproveToken[0] = address(dai);
            address[] memory _tradeAssets = new address[](1);
            _tradeAssets[0] = address(weth);
            executeParams = encodeExecuteParams(
                0,
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
        address[] memory _assets = new address[](1);
        uint256[] memory _amounts = new uint256[](1);
        uint256[] memory _modes = new uint256[](1);
        _assets[0] = address(dai);
        _amounts[0] = borrowAmt;
        _modes[0] = 0;
        uint256 beforeDebtBalance = wethDebtToken.balanceOf(_marginTrading);
        vm.startPrank(user2);
        //执行 close
        IMarginTrading(_marginTrading).executeFlashLoans(_assets, _amounts, _modes, address(weth), executeParams);
        vm.stopPrank();
        sinkUserTokenBalanceV2(_marginTrading);
        assertEq(wethDebtToken.balanceOf(_marginTrading), beforeDebtBalance - swapOutAmt);
    }

    //deposit 100 DAI borrow 10eth => repay eth
    function testProxyExecuteFlashLoansAllClose() public {
        address _marginTrading = openMarginTradingDAIV2(user1, address(dai), address(weth), 10000 ether, 1 ether);

        //-------------------------- close -----------------------------------//
        vm.prank(user1);
        marginTradingFactory.addFlashLoanProxy(_marginTrading, user2);

        uint256 borrowAmt = 2000 ether;
        // 组装 swap参数
        bytes memory swapParams = getSwapCalldata(address(dai), address(weth), borrowAmt);
        uint256 swapOutAmt = getRouterToAmount(address(dai), address(weth), borrowAmt);
        //组装执行参数
        bytes memory executeParams;
        {
            address[] memory _withdrawAssets = new address[](1);
            _withdrawAssets[0] = address(dai);
            uint256[] memory _withdrawAmounts = new uint256[](1);
            _withdrawAmounts[0] = (borrowAmt * 10009) / 10000;
            uint256[] memory _rateMode = new uint256[](1);
            _rateMode[0] = 0;
            address[] memory _debtTokens = new address[](1);
            _debtTokens[0] = address(wethDebtToken);
            address[] memory _swapApproveToken = new address[](1);
            _swapApproveToken[0] = address(dai);
            address[] memory _tradeAssets = new address[](1);
            _tradeAssets[0] = address(weth);
            executeParams = encodeExecuteParams(
                2,
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
        address[] memory _assets = new address[](1);
        uint256[] memory _amounts = new uint256[](1);
        uint256[] memory _modes = new uint256[](1);
        _assets[0] = address(dai);
        _amounts[0] = borrowAmt;
        _modes[0] = 0;
        uint256 beforeDebtBalance = wethDebtToken.balanceOf(_marginTrading);
        vm.startPrank(user2);
        //执行 close
        IMarginTrading(_marginTrading).executeFlashLoans(_assets, _amounts, _modes, address(weth), executeParams);
        vm.stopPrank();
        sinkUserTokenBalanceV2(_marginTrading);
        assertEq(wethDebtToken.balanceOf(_marginTrading), 0);
    }

    function testLiquidationCall() public {
        address _marginTrading = openMarginTradingDAIV2(user1, address(dai), address(weth), 10000 ether, 10 ether);

        approveTokenTarget(address(daiAToken), address(lendingPoolV2), _marginTrading);

        faucetWeth(user2, 100 ether);

        vm.startPrank(user2);
        lendingPoolV2.liquidationCall(address(dai), address(wethDebtToken), _marginTrading, 5 ether, true);
        vm.stopPrank();

        sinkUserTokenBalanceV2(_marginTrading);
        sinkUserTokenBalanceV2(user2);

        assertEq(wethDebtToken.balanceOf(_marginTrading), 5 ether);
    }

    //deposit 100 DAI borrow 1eth
    function testExecuteFlashLoansOpenSwapError() public {
        faucet(address(dai), user1, 100 ether);
        faucetWeth(address(lendingPoolV3), 10000 ether);
        uint256 depositAmt = 100 ether;
        uint256 borrowAmt = 1 ether;
        vm.startPrank(user1);
        address _marginTrading = createMarginTradingContractV2();
        // 组装 swap参数
        bytes memory swapParams = getSwapErrorCalldata();
        bytes memory executeParams;
        //组装执行参数
        {
            address[] memory _withdrawAssets = new address[](1);
            uint256[] memory _withdrawAmounts = new uint256[](1);
            uint256[] memory _rateMode = new uint256[](1);
            address[] memory _debtTokens = new address[](1);
            address[] memory _swapApproveToken = new address[](1);
            _swapApproveToken[0] = address(weth);
            address[] memory _tradeAssets = new address[](1);
            _tradeAssets[0] = address(dai);
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
        address[] memory _assets = new address[](1);
        _assets[0] = address(weth);
        uint256[] memory _amounts = new uint256[](1);
        _amounts[0] = borrowAmt;
        uint256[] memory _modes = new uint256[](1);
        _modes[0] = 1;
        address _mainToken = address(weth);
        // 先存款
        marginTradingFactoryV2.depositMarginTradingERC20(_marginTrading, address(dai), depositAmt, true, 1);
        //再执行
        vm.expectRevert(bytes("dodoswap fail"));
        IMarginTrading(_marginTrading).executeFlashLoans(_assets, _amounts, _modes, _mainToken, executeParams);
        // vm.stopPrank();
        sinkUserTokenBalanceV2(_marginTrading);
    }

    //deposit 100 DAI borrow 1eth
    function testExecuteFlashLoansCollateralError() public {
        faucet(address(dai), user1, 100 ether);
        faucetWeth(address(lendingPoolV3), 10000 ether);
        uint256 depositAmt = 100 ether;
        uint256 borrowAmt = 1 ether;
        vm.startPrank(user1);
        address _marginTrading = createMarginTradingContractV2();
        // 组装 swap参数
        bytes memory swapParams = getSwapCalldata(address(weth), address(dai), borrowAmt);
        bytes memory executeParams;
        //组装执行参数
        {
            address[] memory _withdrawAssets = new address[](1);
            uint256[] memory _withdrawAmounts = new uint256[](1);
            uint256[] memory _rateMode = new uint256[](1);
            address[] memory _debtTokens = new address[](1);
            address[] memory _swapApproveToken = new address[](1);
            _swapApproveToken[0] = address(weth);
            address[] memory _tradeAssets = new address[](1);
            _tradeAssets[0] = address(dai);
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
        address[] memory _assets = new address[](1);
        _assets[0] = address(weth);
        uint256[] memory _amounts = new uint256[](1);
        _amounts[0] = borrowAmt;
        uint256[] memory _modes = new uint256[](1);
        _modes[0] = 1;
        address _mainToken = address(weth);
        // 先存款
        marginTradingFactoryV2.depositMarginTradingERC20(_marginTrading, address(dai), depositAmt, true, 1);
        //再执行
        vm.expectRevert(bytes("Insufficient collateral"));
        IMarginTrading(_marginTrading).executeFlashLoans(_assets, _amounts, _modes, _mainToken, executeParams);
        vm.stopPrank();
        sinkUserTokenBalanceV2(_marginTrading);
        assertEq(wethDebtToken.balanceOf(_marginTrading), 0 ether);
    }

    //deposit 1000 DAI borrow 1eth => repay eth
    function testExecuteFlashLoansAllCloseSwapError() public {
        address _marginTrading = openMarginTradingDAIV3(user1, address(dai), address(weth), 1000 ether, 1 ether);
        console2.log("---------------close--------------------");
        //-------------------------- close -----------------------------------//

        uint256 borrowAmt = 200 ether;
        // 组装 swap参数
        bytes memory swapParams = getSwapCalldata(address(dai), address(weth), borrowAmt);
        uint256 swapOutAmt = getRouterToAmount(address(dai), address(weth), borrowAmt);
        //组装执行参数
        bytes memory executeParams;
        {
            address[] memory _withdrawAssets = new address[](1);
            _withdrawAssets[0] = address(dai);
            uint256[] memory _withdrawAmounts = new uint256[](1);
            _withdrawAmounts[0] = (borrowAmt * 10009) / 10000;
            uint256[] memory _rateMode = new uint256[](1);
            _rateMode[0] = 0;
            address[] memory _debtTokens = new address[](1);
            _debtTokens[0] = address(wethDebtToken);
            address[] memory _swapApproveToken = new address[](1);
            _swapApproveToken[0] = address(dai);
            address[] memory _tradeAssets = new address[](1);
            _tradeAssets[0] = address(weth);
            executeParams = encodeExecuteParams(
                2,
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
        address[] memory _assets = new address[](1);
        uint256[] memory _amounts = new uint256[](1);
        uint256[] memory _modes = new uint256[](1);
        _assets[0] = address(dai);
        _amounts[0] = borrowAmt;
        _modes[0] = 0;
        uint256 beforeDebtBalance = wethDebtToken.balanceOf(_marginTrading);
        vm.startPrank(user1);
        //执行 close
        vm.expectRevert();
        IMarginTrading(_marginTrading).executeFlashLoans(_assets, _amounts, _modes, address(weth), executeParams);
        vm.stopPrank();
        sinkUserTokenBalanceV3(_marginTrading);
        assertEq(wethDebtToken.balanceOf(_marginTrading), 1 ether);
    }

    function testExecuteFlashLoansWithdrawEthError() public {
        faucetWeth(address(lendingPoolV3), 10000 ether);
        address _marginTrading = openMarginTradingDAIV3(user1, address(weth), address(dai), 1 ether, 1500 ether);
        uint256 beforeUserBalance = weth.balanceOf(user1);
        sinkUserTokenBalanceV3(_marginTrading);
        vm.startPrank(user1);
        console2.log("-------- user1 -------------");
        sinkUserTokenBalanceV3(user1);
        console2.log("-------- _marginTrading -------------");
        sinkUserTokenBalanceV3(_marginTrading);
        vm.expectRevert();
        IMarginTrading(_marginTrading).withdrawERC20(address(weth), 3 ether, true, 2);
        vm.stopPrank();
        console2.log("-------- user1 -------------");
        sinkUserTokenBalanceV3(user1);
        console2.log("-------- _marginTrading -------------");
        sinkUserTokenBalanceV3(_marginTrading);
        assertEq(beforeUserBalance, weth.balanceOf(user1));
    }

    function testExecuteFlashLoansWithdrawEthErrorTwo() public {
        faucetWeth(address(lendingPoolV3), 10000 ether);
        address _marginTrading = openMarginTradingDAIV3(user1, address(weth), address(dai), 1 ether, 1500 ether);
        uint256 beforeUserBalance = weth.balanceOf(user2);
        sinkUserTokenBalanceV3(_marginTrading);
        vm.startPrank(user2);
        console2.log("-------- user1 -------------");
        sinkUserTokenBalanceV3(user1);
        console2.log("-------- _marginTrading -------------");
        sinkUserTokenBalanceV3(_marginTrading);
        vm.expectRevert();
        IMarginTrading(_marginTrading).withdrawERC20(address(weth), 3 ether, true, 2);
        vm.stopPrank();
        console2.log("-------- user1 -------------");
        sinkUserTokenBalanceV3(user2);
        console2.log("-------- _marginTrading -------------");
        sinkUserTokenBalanceV3(_marginTrading);
        assertEq(beforeUserBalance, weth.balanceOf(user2));
    }
}
