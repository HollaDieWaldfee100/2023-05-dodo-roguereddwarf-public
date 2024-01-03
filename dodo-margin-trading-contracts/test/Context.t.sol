// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../../contracts/mock/MockERC20.sol";
import {DODOApprove} from "../../contracts/mock/DODOApprove.sol";
import {DODOApproveProxy} from "../../contracts/mock/DODOApproveProxy.sol";
import {WETH9} from "../../contracts/mock/WETH9.sol";
import {MarginTrading} from "../../contracts/marginTrading/MarginTrading.sol";
import {MarginTradingFactory} from "../../contracts/marginTrading/MarginTradingFactory.sol";
import {MockLendingPool} from "../../contracts/mock/MockLendingPool.sol";
import {MockLendingPoolV2} from "../../contracts/mock/MockLendingPoolV2.sol";
import {MockLendingPoolV3} from "../../contracts/mock/MockLendingPoolV3.sol";
import {MockRouter} from "../../contracts/mock/MockRouter.sol";
import {IMarginTradingFactory} from "../../contracts/marginTrading/interfaces/IMarginTradingFactory.sol";
import {IMarginTrading} from "../../contracts/marginTrading/interfaces/IMarginTrading.sol";

contract Context is Test {
    DODOApprove public dodoApprove;
    DODOApproveProxy public dodoApproveProxy;
    WETH9 public weth;
    MockERC20 public dai;

    MockERC20 public depositToken;
    MockERC20 public borrowToken;
    MockERC20 public aToken;
    MockERC20 public debtToken;
    MockLendingPool public lendingPool;

    MockLendingPoolV2 public lendingPoolV2;
    MockLendingPoolV3 public lendingPoolV3;
    MockERC20 public daiAToken;
    MockERC20 public daiDebtToken;
    MockERC20 public wethAToken;
    MockERC20 public wethDebtToken;

    MockRouter public router;

    MarginTradingFactory public marginTradingFactory;
    MarginTradingFactory public marginTradingFactoryV2;

    MarginTrading public marginTradingTemplate;

    MarginTrading public marginTrading;

    address public marginCreator = address(123);
    address public user1 = address(1111);
    address public user2 = address(2222);
    address public user3 = address(3333);

    // ---------- Context ----------

    function contextBasic() public {
        createContracts();
    }

    function contextBasicV2() public {
        createContractsV2();
    }

    // --------------create ----------------------------------//
    function createContractsV2() public {
        createTokens();
        vm.startPrank(marginCreator);
        dodoApprove = new DODOApprove();
        dodoApproveProxy = new DODOApproveProxy(address(dodoApprove));
        dodoApprove.init(marginCreator, address(dodoApproveProxy));
        address[] memory _aToken = new address[](2);
        _aToken[0] = address(daiAToken);
        _aToken[1] = address(wethAToken);
        address[] memory _debtToken = new address[](2);
        _debtToken[0] = address(daiDebtToken);
        _debtToken[1] = address(wethDebtToken);
        lendingPoolV2 = new MockLendingPoolV2(
            address(dai),
            address(weth),
            _aToken,
            _debtToken
        );
        lendingPoolV3 = new MockLendingPoolV3(
            address(dai),
            address(weth),
            _aToken,
            _debtToken
        );
        lendingPoolV3.setTokenPrice(address(dai), 1);
        lendingPoolV3.setTokenPrice(address(weth), 2000);

        marginTrading = new MarginTrading();
        marginTradingFactory = new MarginTradingFactory(
            address(lendingPoolV2),
            address(weth),
            address(dodoApproveProxy),
            address(marginTrading)
        );
        marginTradingFactoryV2 = new MarginTradingFactory(
            address(lendingPoolV3),
            address(weth),
            address(dodoApproveProxy),
            address(marginTrading)
        );
        router = new MockRouter(dodoApproveProxy);
        vm.stopPrank();

        faucet(address(depositToken), address(router), 200000 ether);
        faucetWeth(address(router), 100 ether);

        address[] memory proxies = new address[](3);
        proxies[0] = address(marginTradingFactory);
        proxies[1] = address(marginTradingFactoryV2);
        proxies[2] = address(router);
        dodoApproveProxy.init(marginCreator, proxies);
    }

    function createContracts() public {
        createTokens();
        vm.startPrank(marginCreator);
        dodoApprove = new DODOApprove();
        dodoApproveProxy = new DODOApproveProxy(address(dodoApprove));
        dodoApprove.init(marginCreator, address(dodoApproveProxy));

        lendingPool = new MockLendingPool(
            depositToken,
            borrowToken,
            aToken,
            debtToken
        );

        marginTrading = new MarginTrading();
        marginTradingFactory = new MarginTradingFactory(
            address(lendingPool),
            address(weth),
            address(dodoApproveProxy),
            address(marginTrading)
        );
        router = new MockRouter(dodoApproveProxy);
        vm.stopPrank();

        faucet(address(depositToken), address(router), 160000 ether);
        faucetWeth(address(router), 100 ether);

        address[] memory proxies = new address[](2);
        proxies[0] = address(marginTradingFactory);
        proxies[1] = address(router);
        dodoApproveProxy.init(marginCreator, proxies);
    }

    function createTokens() public {
        dai = new MockERC20("DAI", "DAI", 18);
        aToken = new MockERC20("aToken", "aToken", 18);
        debtToken = new MockERC20("debtToken", "debtToken", 18);
        createWETH();
        borrowToken = MockERC20(address(weth));
        depositToken = MockERC20(address(dai));

        daiAToken = new MockERC20("DAIAToken", "DAIAToken", 18);
        daiDebtToken = new MockERC20("DAIDebtToken", "DAIDebtToken", 18);
        wethAToken = new MockERC20("WETHAToken", "WETHAToken", 18);
        wethDebtToken = new MockERC20("WETHDebtToken", "WETHDebtToken", 18);
    }

    function createWETH() public {
        weth = new WETH9();
    }

    function approveTokenTarget(address _token, address _target, address _user) public {
        vm.prank(_user);
        approveToken(address(_target), address(_token));
    }

    function approveAllTokenV2() public {
        vm.startPrank(marginCreator);
        approveToken(address(dodoApprove), address(dai));
        approveToken(address(dodoApprove), address(weth));
        approveToken(address(lendingPoolV2), address(dai));
        approveToken(address(lendingPoolV2), address(weth));
        approveToken(address(lendingPoolV2), address(daiAToken));
        approveToken(address(lendingPoolV2), address(daiDebtToken));
        approveToken(address(lendingPoolV2), address(wethAToken));
        approveToken(address(lendingPoolV2), address(wethDebtToken));

        approveToken(address(lendingPoolV3), address(dai));
        approveToken(address(lendingPoolV3), address(weth));
        approveToken(address(lendingPoolV3), address(daiAToken));
        approveToken(address(lendingPoolV3), address(daiDebtToken));
        approveToken(address(lendingPoolV3), address(wethAToken));
        approveToken(address(lendingPoolV3), address(wethDebtToken));
        vm.stopPrank();
        vm.startPrank(user1);
        approveToken(address(dodoApprove), address(dai));
        approveToken(address(dodoApprove), address(weth));
        approveToken(address(lendingPoolV2), address(dai));
        approveToken(address(lendingPoolV2), address(weth));
        approveToken(address(lendingPoolV2), address(daiAToken));
        approveToken(address(lendingPoolV2), address(daiDebtToken));
        approveToken(address(lendingPoolV2), address(wethAToken));
        approveToken(address(lendingPoolV2), address(wethDebtToken));
        approveToken(address(lendingPoolV3), address(dai));
        approveToken(address(lendingPoolV3), address(weth));
        approveToken(address(lendingPoolV3), address(daiAToken));
        approveToken(address(lendingPoolV3), address(daiDebtToken));
        approveToken(address(lendingPoolV3), address(wethAToken));
        approveToken(address(lendingPoolV3), address(wethDebtToken));
        vm.stopPrank();
        vm.startPrank(user2);
        approveToken(address(dodoApprove), address(dai));
        approveToken(address(dodoApprove), address(weth));
        approveToken(address(lendingPoolV2), address(dai));
        approveToken(address(lendingPoolV2), address(weth));
        approveToken(address(lendingPoolV2), address(daiAToken));
        approveToken(address(lendingPoolV2), address(daiDebtToken));
        approveToken(address(lendingPoolV2), address(wethAToken));
        approveToken(address(lendingPoolV2), address(wethDebtToken));
        approveToken(address(lendingPoolV3), address(dai));
        approveToken(address(lendingPoolV3), address(weth));
        approveToken(address(lendingPoolV3), address(daiAToken));
        approveToken(address(lendingPoolV3), address(daiDebtToken));
        approveToken(address(lendingPoolV3), address(wethAToken));
        approveToken(address(lendingPoolV3), address(wethDebtToken));
        vm.stopPrank();
    }

    function approveAllToken() public {
        vm.startPrank(marginCreator);
        approveToken(address(dodoApprove), address(depositToken));
        approveToken(address(dodoApprove), address(borrowToken));
        approveToken(address(lendingPool), address(depositToken));
        approveToken(address(lendingPool), address(borrowToken));
        approveToken(address(lendingPool), address(aToken));
        approveToken(address(lendingPool), address(debtToken));
        vm.stopPrank();
        vm.startPrank(user1);
        approveToken(address(dodoApprove), address(depositToken));
        approveToken(address(dodoApprove), address(borrowToken));
        approveToken(address(lendingPool), address(depositToken));
        approveToken(address(lendingPool), address(borrowToken));
        approveToken(address(lendingPool), address(aToken));
        approveToken(address(lendingPool), address(debtToken));
        vm.stopPrank();
        vm.startPrank(user2);
        approveToken(address(dodoApprove), address(depositToken));
        approveToken(address(dodoApprove), address(borrowToken));
        approveToken(address(lendingPool), address(depositToken));
        approveToken(address(lendingPool), address(borrowToken));
        approveToken(address(lendingPool), address(aToken));
        approveToken(address(lendingPool), address(debtToken));
        vm.stopPrank();
    }

    // --------------help ----------------------------------//
    function setLendingPoolToken(MockERC20 _depositToken, MockERC20 _borrowToken) public {
        lendingPool.setToken(_depositToken, _borrowToken);
    }

    function faucet(address token, address to, uint256 amount) public {
        MockERC20(token).mint(to, amount);
    }

    function faucetWeth(address to, uint256 amount) public {
        vm.startPrank(marginCreator);
        vm.deal(marginCreator, amount);
        weth.deposit{value: amount}();
        weth.transfer(to, amount);
        vm.stopPrank();
    }

    function encodeFlashLoan(
        address[] memory _assets,
        uint256[] memory _amounts,
        uint256[] memory _modes,
        address _mainToken,
        bytes memory _params
    ) public pure returns (bytes memory result) {
        result = abi.encode(_assets, _amounts, _modes, _mainToken, _params);
    }

    function encodeExecuteParams(
        uint8 _flag,
        address _swapAddress,
        address _swapApproveTarget,
        address[] memory _swapApproveToken,
        bytes memory _swapParams,
        address[] memory _tradeAssets,
        address[] memory _withdrawAssets,
        uint256[] memory _withdrawAmounts,
        uint256[] memory _rateMode,
        address[] memory _debtTokens
    ) public pure returns (bytes memory result) {
        result = abi.encode(
            _flag,
            _swapAddress,
            _swapApproveTarget,
            _swapApproveToken,
            _swapParams,
            _tradeAssets,
            _withdrawAssets,
            _withdrawAmounts,
            _rateMode,
            _debtTokens
        );
    }

    function encodeDepositParams(
        uint8 _depositFlag, //1- erc20 2-eth
        address _tokenAddres,
        uint256 _depositAmount
    ) public pure returns (bytes memory result) {
        result = abi.encode(_depositFlag, _tokenAddres, _depositAmount);
    }

    function getSwapCalldata(
        address fromToken,
        address toToken,
        uint256 fromAmount
    ) public pure returns (bytes memory swapParams) {
        swapParams = abi.encodeWithSignature("swap(address,address,uint256)", fromToken, toToken, fromAmount);
    }

    function getSwapErrorCalldata() public pure returns (bytes memory swapParams) {
        swapParams = abi.encodeWithSignature("swapswapError()");
    }

    function getRouterToAmount(
        address fromToken,
        address toToken,
        uint256 fromAmount
    ) public view returns (uint256 toAmount) {
        uint256 fromTokenBalance = MockERC20(fromToken).balanceOf(address(router));
        uint256 toTokenBalance = MockERC20(toToken).balanceOf(address(router));
        toAmount = toTokenBalance - (toTokenBalance * fromTokenBalance) / (fromTokenBalance + fromAmount);
    }

    function liquidationMarginTrading(address _margin, uint256 _amount, bool _receiveAToken) public {
        lendingPool.liquidationCall(address(0), address(0), _margin, _amount, _receiveAToken);
    }

    // Make forge coverage ignore
    function testSuccess() public {
        assertEq(true, true);
    }

    function approveToken(address _address, address _tokenAddress) public {
        MockERC20(_tokenAddress).approve(_address, type(uint256).max);
    }

    function sinkUserTokenBalanceV2(address _address) public view {
        console2.log("dai balance:", dai.balanceOf(_address) / 1e18);
        console2.log("weth balance:", weth.balanceOf(_address) / 1e18);
        console2.log("daiAtoken balance:", daiAToken.balanceOf(_address) / 1e18);
        console2.log("wethAtoken balance:", wethAToken.balanceOf(_address) / 1e18);
        console2.log("daiDebtToken balance:", daiDebtToken.balanceOf(_address) / 1e18);
        console2.log("wethDebtToken balance:", wethDebtToken.balanceOf(_address) / 1e18);
    }

    function sinkUserTokenBalanceV3(address _address) public view {
        console2.log("dai balance:", dai.balanceOf(_address) / 1e16);
        console2.log("weth balance:", weth.balanceOf(_address) / 1e16);
        console2.log("daiAtoken balance:", daiAToken.balanceOf(_address) / 1e16);
        console2.log("wethAtoken balance:", wethAToken.balanceOf(_address) / 1e16);
        console2.log("daiDebtToken balance:", daiDebtToken.balanceOf(_address) / 1e16);
        console2.log("wethDebtToken balance:", wethDebtToken.balanceOf(_address) / 1e16);
        console2.log("health:", lendingPoolV3.getHealth(_address) / 1e16);
    }

    function sinkUserTokenBalance(address _address)
        public
        view
        returns (uint256 dtb, uint256 btb, uint256 ab, uint256 debtb)
    {
        dtb = MockERC20(depositToken).balanceOf(_address);
        btb = MockERC20(borrowToken).balanceOf(_address);
        ab = MockERC20(aToken).balanceOf(_address);
        debtb = MockERC20(debtToken).balanceOf(_address);
        console2.log(_address, " depositToken balance:", dtb / 1e18);
        console2.log(_address, " borrowToken balance:", btb / 1e18);
        console2.log(_address, " aToken balance:", ab / 1e18);
        console2.log(_address, " debtToken balance:", debtb / 1e18);
        return (dtb, btb, ab, debtb);
    }

    //open Trading
    //deposit 100 DAI borrow 1eth
    function openMarginTradingDAI(address _user) public {
        faucet(address(depositToken), _user, 100 ether);
        faucetWeth(address(lendingPool), 10000 ether);
        uint256 depositAmt = 100 ether;
        uint256 borrowAmt = 1 ether;
        // 先预测地址
        vm.startPrank(_user);
        (, uint256 _isolateNum) = marginTradingFactory.getUserMarginTradingNum(_user);
        address marginTradingAddress = marginTradingFactory.getCreateMarginTradingAddress(_isolateNum, 2, _user);
        // 组装存款参数
        bytes memory depositParams = encodeDepositParams(1, address(depositToken), depositAmt);
        // 组装 swap参数
        bytes memory swapParams = getSwapCalldata(address(borrowToken), address(depositToken), borrowAmt);
        uint256 swapOutAmt = getRouterToAmount(address(borrowToken), address(depositToken), borrowAmt);
        bytes memory executeParams;
        //组装执行参数
        {
            address[] memory _withdrawAssets = new address[](1);
            uint256[] memory _withdrawAmounts = new uint256[](1);
            uint256[] memory _rateMode = new uint256[](1);
            address[] memory _debtTokens = new address[](1);
            address[] memory _swapApproveToken = new address[](1);
            _swapApproveToken[0] = address(borrowToken);
            address[] memory _tradeAssets = new address[](1);
            _tradeAssets[0] = address(depositToken);
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
            _assets[0] = address(borrowToken);
            uint256[] memory _amounts = new uint256[](1);
            _amounts[0] = borrowAmt;
            uint256[] memory _modes = new uint256[](1);
            _modes[0] = 1;
            address _mainToken = address(borrowToken);
            flashLoanParams = encodeFlashLoan(_assets, _amounts, _modes, _mainToken, executeParams);
        }
        //执行
        marginTradingFactory.createMarginTrading(2, depositParams, flashLoanParams);
        vm.stopPrank();
        sinkUserTokenBalance(marginTradingAddress);
        assertEq(aToken.balanceOf(marginTradingAddress), depositAmt + swapOutAmt);
        assertEq(debtToken.balanceOf(marginTradingAddress), borrowAmt);
    }

    //deposit 100weth  borrow 100 DAI
    function openMarginTradingWeth(address _user) public {
        address _depositToken = address(weth);
        address _borrowToken = address(dai);

        faucetWeth(_user, 100 ether);
        faucet(address(_borrowToken), address(lendingPool), 10000 ether);
        faucetWeth(address(lendingPool), 10000 ether);
        setLendingPoolToken(MockERC20(address(weth)), dai);

        uint256 depositAmt = 100 ether;
        uint256 borrowAmt = 100 ether;
        // 先预测地址
        vm.startPrank(_user);
        (, uint256 _isolateNum) = marginTradingFactory.getUserMarginTradingNum(_user);
        address marginTradingAddress = marginTradingFactory.getCreateMarginTradingAddress(_isolateNum, 2, _user);
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

    //createMarginTrading no deposit no borrow
    function createMarginTradingContract() public returns (address _marginTrading) {
        bytes memory depositParams = new bytes(0);
        bytes memory flashLoanParams = new bytes(0);
        //执行
        _marginTrading = marginTradingFactory.createMarginTrading(2, depositParams, flashLoanParams);
    }

    function createMarginTradingContractV2() public returns (address _marginTrading) {
        bytes memory depositParams = new bytes(0);
        bytes memory flashLoanParams = new bytes(0);
        //执行
        _marginTrading = marginTradingFactoryV2.createMarginTrading(2, depositParams, flashLoanParams);
    }

    //open Trading
    //deposit 100 DAI borrow 10eth
    function openMarginTradingDAIV2(
        address _user,
        address _depositToken,
        address _borrowToken,
        uint256 _depositAmt,
        uint256 _borrowAmt
    ) public returns (address _marginTrading) {
        faucet(address(dai), _user, 100000 ether);
        faucetWeth(_user, 10000 ether);
        faucetWeth(address(lendingPoolV2), 10000 ether);
        faucet(address(dai), address(lendingPoolV2), 1000000 ether);
        vm.startPrank(_user);
        _marginTrading = createMarginTradingContract();
        // 组装 swap参数
        bytes memory swapParams = getSwapCalldata(_borrowToken, _depositToken, _borrowAmt);
        bytes memory executeParams;
        //组装执行参数
        {
            address[] memory _withdrawAssets = new address[](1);
            uint256[] memory _withdrawAmounts = new uint256[](1);
            uint256[] memory _rateMode = new uint256[](1);
            address[] memory _debtTokens = new address[](1);
            address[] memory _swapApproveToken = new address[](1);
            _swapApproveToken[0] = _borrowToken;
            address[] memory _tradeAssets = new address[](1);
            _tradeAssets[0] = _depositToken;
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
        _assets[0] = _borrowToken;
        uint256[] memory _amounts = new uint256[](1);
        _amounts[0] = _borrowAmt;
        uint256[] memory _modes = new uint256[](1);
        _modes[0] = 1;
        address _mainToken = address(weth);
        // 先存款
        marginTradingFactory.depositMarginTradingERC20(_marginTrading, _depositToken, _depositAmt, true, 1);
        //再执行
        IMarginTrading(_marginTrading).executeFlashLoans(_assets, _amounts, _modes, _mainToken, executeParams);
        vm.stopPrank();
        sinkUserTokenBalanceV2(_marginTrading);
        assertEq(MockERC20(lendingPoolV2.debtToken(_borrowToken)).balanceOf(_marginTrading), _borrowAmt);
    }

    function openMarginTradingDAIV3(
        address _user,
        address _depositToken,
        address _borrowToken,
        uint256 _depositAmt,
        uint256 _borrowAmt
    ) public returns (address _marginTrading) {
        faucet(address(dai), _user, 100000 ether);
        faucetWeth(_user, 10000 ether);
        faucetWeth(address(lendingPoolV3), 10000 ether);
        faucet(address(dai), address(lendingPoolV3), 1000000 * 2000 ether);
        vm.startPrank(_user);
        _marginTrading = createMarginTradingContractV2();
        // 组装 swap参数
        bytes memory swapParams = getSwapCalldata(_borrowToken, _depositToken, _borrowAmt);
        bytes memory executeParams;
        //组装执行参数
        {
            address[] memory _withdrawAssets = new address[](1);
            uint256[] memory _withdrawAmounts = new uint256[](1);
            uint256[] memory _rateMode = new uint256[](1);
            address[] memory _debtTokens = new address[](1);
            address[] memory _swapApproveToken = new address[](1);
            _swapApproveToken[0] = _borrowToken;
            address[] memory _tradeAssets = new address[](1);
            _tradeAssets[0] = _depositToken;
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
        _assets[0] = _borrowToken;
        uint256[] memory _amounts = new uint256[](1);
        _amounts[0] = _borrowAmt;
        uint256[] memory _modes = new uint256[](1);
        _modes[0] = 1;
        address _mainToken = address(weth);
        // 先存款
        marginTradingFactoryV2.depositMarginTradingERC20(_marginTrading, _depositToken, _depositAmt, true, 1);
        //再执行
        IMarginTrading(_marginTrading).executeFlashLoans(_assets, _amounts, _modes, _mainToken, executeParams);
        vm.stopPrank();
        sinkUserTokenBalanceV3(_marginTrading);
        assertEq(MockERC20(lendingPoolV3.debtToken(_borrowToken)).balanceOf(_marginTrading), _borrowAmt);
    }
}
