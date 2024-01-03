// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.15;

interface IMarginTradingFactory {
    //---------------event-----------------
    event MarginTradingCreated(
        address indexed userAddress, address indexed marginAddress, uint256 userMarginNum, uint8 _flag
    );

    event DepositMarginTradingERC20(
        address _marginTradingAddress, address _marginAddress, uint256 _marginAmount, bool _margin, uint8 _flag
    );

    event DepositMarginTradingETH(address _marginTradingAddress, uint256 _marginAmount, bool _margin, uint8 _flag);

    event ExecuteMarginTradingFlashLoans(
        address indexed _marginTradingAddress, address[] assets, uint256[] amounts, uint256[] modes
    );

    //---------------view-----------------

    function getCreateMarginTradingAddress(
        uint256 _num,
        uint8 _flag,
        address _user
    ) external view returns (address _ad);

    function getUserMarginTradingNum(address _user) external view returns (uint256 _crossNum, uint256 _isolateNum);

    function isAllowedProxy(address _marginTradingAddress, address _proxy) external view returns (bool);

    //---------------function-----------------

    function multicall(bytes[] calldata data) external payable returns (bytes[] memory results);

    function createMarginTrading(
        uint8 _flag,
        bytes calldata depositParams,
        bytes calldata executeParams
    ) external payable returns (address margin);

    function executeMarginTradingFlashLoans(
        address _marginTradingAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata modes,
        address mainToken,
        bytes calldata params
    ) external;

    function depositMarginTradingERC20(
        address _marginTradingAddress,
        address _marginAddress,
        uint256 _marginAmount,
        bool _margin,
        uint8 _flag
    ) external;

    function depositMarginTradingETH(address _marginTradingAddress, bool _margin, uint8 _flag) external payable;

    function addFlashLoanProxy(address _marginTradingAddress, address _proxy) external;

    function removeFlashLoanProxy(address _marginTradingAddress, address _oldProxy) external;
}
