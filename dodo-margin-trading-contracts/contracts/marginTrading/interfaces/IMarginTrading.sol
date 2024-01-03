// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.15;

interface IMarginTrading {
    //---------------event-----------------
    // @audit-ok
    event FlashLoans(address[] assets, uint256[] amounts, uint256[] modes, address mainToken);
    // @audit-ok
    event OpenPosition(
        address indexed swapAddress, address[] swapApproveToken, address[] tradAssets, uint256[] tradAmounts
    );
    // @audit-ok
    event ClosePosition(
        uint8 _flag,
        address indexed swapAddress,
        address[] swapApproveToken,
        address[] tradAssets,
        uint256[] tradAmounts,
        address[] withdrawAssets,
        uint256[] withdrawAmounts,
        uint256[] _rateMode,
        uint256[] _returnAmounts
    );
    // @audit-ok
    event LendingPoolWithdraw(address indexed asset, uint256 indexed amount, uint8 _flag);
    // @audit-ok
    event LendingPoolDeposit(address indexed asset, uint256 indexed amount, uint8 _flag);
    // @audit-ok
    event LendingPoolRepay(address indexed asset, uint256 indexed amount, uint256 indexed rateMode, uint8 _flag);
    // @audit-ok
    event WithdrawERC20(address indexed marginAddress, uint256 indexed marginAmount, bool indexed margin, uint8 _flag);
    // @audit-ok
    event WithdrawETH(uint256 indexed marginAmount, bool indexed margin, uint8 _flag);

    //---------------view-----------------
    // @audit-ok
    function user() external view returns (address _userAddress);
    // @audit-ok
    function getContractAddress() external view returns (address _lendingPoolAddress, address _WETHAddress);

    //---------------function-----------------
    // @audit-ok
    function multicall(bytes[] calldata data) external payable returns (bytes[] memory results);

    // @audit-ok
    function executeFlashLoans(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata modes,
        address mainToken,
        bytes calldata params
    ) external;
    // @audit-ok
    function lendingPoolWithdraw(address _asset, uint256 _amount, uint8 _flag) external;
    // @audit-ok
    function lendingPoolDeposit(address _asset, uint256 _amount, uint8 _flag) external;
    // @audit-ok
    function lendingPoolRepay(address _repayAsset, uint256 _repayAmt, uint256 _rateMode, uint8 _flag) external;
    // @audit-ok
    function withdrawERC20(address _marginAddress, uint256 _marginAmount, bool _margin, uint8 _flag) external;
    // @audit-ok
    function withdrawETH(bool _margin, uint256 _marginAmount, uint8 _flag) external payable;
    // @audit-ok
    function initialize(address _lendingPool, address _weth, address _user) external;
}
