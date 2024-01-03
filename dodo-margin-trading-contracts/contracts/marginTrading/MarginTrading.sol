// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.15;

import {ILendingPool, IFlashLoanReceiver} from "../aaveLib/Interfaces.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol"; // @audit-ok for the initialization logic
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IMarginTrading} from "./interfaces/IMarginTrading.sol"; // @audit-ok
import {IMarginTradingFactory} from "./interfaces/IMarginTradingFactory.sol"; // @audit-ok
import {IWETH} from "./interfaces/IWETH.sol";
import {Types} from "./Types.sol"; // @audit-ok

import "forge-std/console.sol";
/**
 * @author  DODO
 * @title   MarginTrading
 * @dev     To save contract size, most of the function implements are moved to LiquidationLibrary.
 * @notice  This contract serves as a user-managed asset contract, responsible for interacting with Aave, including functions such as opening, closing, repaying, and withdrawing.
 */

/* @audit-ok
missing ability to claim rewards
https://solodit.xyz/issues/12289
; reported
*/
contract MarginTrading is OwnableUpgradeable, IMarginTrading, IFlashLoanReceiver {
    using SafeERC20 for IERC20;

    ILendingPool internal lendingPool;

    IWETH internal WETH;

    address private _USER;

    // @audit-ok
    modifier onlyUser() {
        require(_USER == msg.sender, "caller is not the user");
        _;
    }

    // @audit-ok
    modifier onlyLendingPool() {
        require(address(lendingPool) == msg.sender, "caller is not the lendingPool");
        _;
    }

    // @audit-ok
    modifier onlyDeposit() {
        require(_USER == msg.sender || owner() == msg.sender, "caller is unauthorized");
        _;
    }

    /* @audit-info
    used in executeFlashLoans function
    */
    modifier onlyFlashLoan() {
        require(
            _USER == msg.sender || owner() == msg.sender
                || IMarginTradingFactory(owner()).isAllowedProxy(address(this), msg.sender),
            "caller is unauthorized"
        );
        _;
    }

    /// @notice Obtaining the address of the user who owns this contract.
    /// @return _userAddress User address
    // @audit-ok
    function user() external view returns (address _userAddress) {
        return _USER;
    }

    /// @notice Get owner address
    /// @return _ad Owner address
    // @audit-ok
    function getOwner() external view returns (address _ad) {
        _ad = owner();
    }

    /// @notice Query the addresses of relevant external contracts.
    /// @return _lendingPoolAddress lendingPool address
    /// @return _WETHAddress weth address
    // @audit-ok
    function getContractAddress() external view returns (address _lendingPoolAddress, address _WETHAddress) {
        return (address(lendingPool), address(WETH));
    }

    // @audit-ok
    function initialize(address _lendingPool, address _weth, address _user) external initializer {
        __Ownable_init();
        lendingPool = ILendingPool(_lendingPool);
        WETH = IWETH(_weth);
        _USER = _user;
    }

    receive() external payable {}

    // ============ Functions ============

    /// @notice Execution methods for opening and closing.
    /// @dev Execute a flash loan and pass the parameters to the executeOperation method.
    /// @param assets Borrowing assets
    /// @param amounts Borrowing assets amounts
    /// @param modes Borrowing assets premiums
    /// @param mainToken initiator address
    /// @param params The parameters for the execution logic.
    // @audit-ok
    function executeFlashLoans(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata modes,
        address mainToken, // @audit-ok what is the purpose of this? controllable by user; only used in event
        bytes calldata params
    ) external onlyFlashLoan {
        address receiverAddress = address(this);

        // the various assets to be flashed

        // the amount to be flashed for each asset

        // 0 = no debt, 1 = stable, 2 = variable

        address onBehalfOf = address(this);
        // bytes memory params = "";
        lendingPool.flashLoan(receiverAddress, assets, amounts, modes, onBehalfOf, params, Types.REFERRAL_CODE);
        emit FlashLoans(assets, amounts, modes, mainToken);
    }

    /// @notice LendingPool flashloan callback function, returns true upon successful execution.
    /// @dev It internally implements three operations: partial closure, full closure, and opening.
    /// @dev Opening: Borrowing token through flash loan, swapping it into deposit token, and depositing it into Aave to complete the opening process.
    /// @dev Partial closure: Borrowing Aave deposit token through flash loan, swapping it into borrowed token, repaying according to the balance, then extracting token from Aave deposit to repay the flash loan.
    /// @dev Full closure: Borrowing Aave deposit token through flash loan, swapping it into borrowed token, repaying all debts, returning the remaining debt tokens to the user, then extracting token from Aave deposit to repay the flash loan.
    /// @param _assets Borrowing assets
    /// @param _amounts Borrowing assets amounts
    /// @param _premiums Borrowing assets premiums
    /// @param _initiator initiator address
    /// @param _params The parameters for the execution logic.
    /// @return Returns true upon successful execution.
    // @audit-ok
    function executeOperation(
        address[] calldata _assets,
        uint256[] calldata _amounts,
        // @audit-ok should this information be used somewhere? to prevent edge cases?; this is not necessary, front-end
        // ensures that calculations are done correctly and flash loan can be repaid
        uint256[] calldata _premiums,
        address _initiator,
        bytes calldata _params
    ) external override onlyLendingPool returns (bool) {
        /* @audit-ok
        there is no check that initiator is address(this)
        so anyone can closetrade, opentrade
        -> High Severity issue
        attacker can call their own "swap contract" and steal funds
        ; reported 
        */
        //decode params exe swap and deposit
        {
            (
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
            ) = abi.decode(
                _params,
                (uint8, address, address, address[], bytes, address[], address[], uint256[], uint256[], address[])
            );
            if (_flag == 0 || _flag == 2) {
                //close
                // @audit-ok correct params
                _closetrade(
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
            if (_flag == 1) {
                //open
                // @audit-ok correct params
                _opentrade(_swapAddress, _swapApproveTarget, _swapApproveToken, _swapParams, _tradeAssets);
            }
        }
        return true;
    }

    /// @notice Withdraws the token collateral from the lending pool
    /// @param _asset Asset token address
    /// @param _amount Asset token Amount
    /// @param _flag Operation flag
    // @audit-ok
    function lendingPoolWithdraw(address _asset, uint256 _amount, uint8 _flag) external onlyUser {
        // @audit-ok flag just used for event
        _lendingPoolWithdraw(_asset, _amount, _flag);
    }

    /// @notice Deposits the token liquidity onto the lending pool as collateral
    /// @param _asset Asset token address
    /// @param _amount Asset token Amount
    /// @param _flag Operation flag
    // @audit-ok
    function lendingPoolDeposit(address _asset, uint256 _amount, uint8 _flag) external onlyDeposit {
        // @audit-ok flag just used for event
        _lendingPoolDeposit(_asset, _amount, _flag);
    }

    /// @notice Repays a borrowed `amount` on a specific reserve, burning the equivalent debt tokens owned
    /// @param _repayAsset Repay asset token address
    /// @param _repayAmt Repay Asset token Amount
    /// @param _rateMode Rate mode 1: stable mode debt, 2: variable mode debt
    /// @param _flag Operation flag
    // @audit-ok
    function lendingPoolRepay(
        address _repayAsset,
        uint256 _repayAmt,
        uint256 _rateMode,
        uint8 _flag
    ) external onlyUser {
        // @audit-ok flag just used for event
        _lendingPoolRepay(_repayAsset, _repayAmt, _rateMode, _flag);
    }

    /// @notice Withdraw ERC20 Token transfer to user
    /// @param _marginAddress ERC20 token address
    /// @param _marginAmount ERC20 token Amount
    /// @param _margin Whether the token source is collateral
    /// @param _flag Operation flag
    // @audit-ok
    function withdrawERC20(
        address _marginAddress,
        uint256 _marginAmount,
        bool _margin,
        uint8 _flag
    ) external onlyUser {
        if (_margin) {
            // @audit-ok flag just used for event
            _lendingPoolWithdraw(_marginAddress, _marginAmount, _flag);
        }
        IERC20(_marginAddress).transfer(msg.sender, _marginAmount);
        emit WithdrawERC20(_marginAddress, _marginAmount, _margin, _flag);
    }

    /// @notice Withdraw ETH send to user
    /// @dev Convert WETH to ETH and send it to the user.
    /// @param _marginAmount ETH Amount
    /// @param _margin Whether the token source is collateral
    /// @param _flag Operation flag
    // @audit-ok
    function withdrawETH(bool _margin, uint256 _marginAmount, uint8 _flag) external payable onlyUser {
        if (_margin) {
            // @audit-ok flag just used for event
            _lendingPoolWithdraw(address(WETH), _marginAmount, _flag);
        }
        WETH.withdraw(_marginAmount);
        _safeTransferETH(msg.sender, _marginAmount);
        emit WithdrawETH(_marginAmount, _margin, _flag);
    }

    /// @notice Call multiple functions in the current contract and return the data from all of them if they all succeed
    /// @param data The encoded function data for each of the calls to make to this contract
    /// @return results The results from each of the calls passed in via data
    // @audit-ok
    function multicall(bytes[] calldata data) public payable onlyUser returns (bytes[] memory results) {
        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(data[i]);

            if (!success) {
                assembly {
                    revert(add(result, 32), mload(result))
                }
            }

            results[i] = result;
        }
    }

    // =========== internal ==========

    /// @notice Execute the open
    /// @dev Authorize the token first, then perform the swap operation. After successful execution, deposit the token into Aave.
    /// @param _swapAddress Swap address
    /// @param _swapApproveTarget Swap Approve address
    /// @param _swapApproveToken The address of the token that requires swap authorization.
    /// @param _swapParams Swap calldata
    /// @param _tradeAssets Deposit to aave token address
    function _opentrade(
        address _swapAddress,
        address _swapApproveTarget,
        address[] memory _swapApproveToken,
        bytes memory _swapParams,
        address[] memory _tradeAssets
    ) internal {
        if (_swapParams.length > 0) {
            // approve to swap route
            for (uint256 i = 0; i < _swapApproveToken.length; i++) {
                IERC20(_swapApproveToken[i]).approve(_swapApproveTarget, type(uint256).max);
            }

            // https://github.com/DODOEX/contractV2/blob/main/contracts/SmartRoute/DODOV2Proxy02.sol#L309
            (bool success,) = _swapAddress.call(_swapParams);
            require(success, "dodoswap fail");
        }
        uint256[] memory _tradeAmounts = new uint256[](_tradeAssets.length);
        for (uint256 i = 0; i < _tradeAssets.length; i++) {
            /* @audit-ok
            balance might not be from the trade?
            need to check balance after - balance before
            they might just be sitting here without intention of using them as margin
            so trade may end up taking more loss than intended

            on the other hand if using balanceAfter - balanceBefore, user needs to manually deposit the remaining
            if he wants. Still I think it's worth reporting this
            ; reported
            */
            _tradeAmounts[i] = IERC20(_tradeAssets[i]).balanceOf(address(this));
            _lendingPoolDeposit(_tradeAssets[i], _tradeAmounts[i], 1);
        }
        emit OpenPosition(_swapAddress, _swapApproveToken, _tradeAssets, _tradeAmounts);
    }

    /// @notice Execute the close
    /// @dev Partial closure: Perform swap authorization, then execute swap and repay according to the balance.
    /// @dev Full closure: Perform swap authorization, then execute swap, repay according to the borrowed amount, and return the excess tokens to the user.
    /// @param _flag Operation flag
    /// @param _swapAddress Swap address
    /// @param _swapApproveTarget Swap Approve address
    /// @param _swapApproveToken The address of the token that requires swap authorization.
    /// @param _swapParams Swap calldata
    /// @param _tradeAssets Swap out token address,borrowing token address
    /// @param _withdrawAssets Swap in token address,deposit to aave token address
    /// @param _withdrawAmounts Swap in token amount,deposit to aave token amount
    /// @param _rateMode Rate mode 1: stable mode debt, 2: variable mode debt
    /// @param _debtTokens Debt token Address
    function _closetrade(
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
    ) internal {
        if (_swapParams.length > 0) {
            // approve to swap route
            for (uint256 i = 0; i < _swapApproveToken.length; i++) {
                IERC20(_swapApproveToken[i]).approve(_swapApproveTarget, type(uint256).max);
            }

            // https://github.com/DODOEX/contractV2/blob/main/contracts/SmartRoute/DODOV2Proxy02.sol#L309
            (bool success,) = _swapAddress.call(_swapParams);
            require(success, "dodoswap fail");
        }
        uint256[] memory _tradeAmounts = new uint256[](_tradeAssets.length);
        /* @audit-info
        full closure (2)
        partial closure (0)
        */
        if (_flag == 2) {
            for (uint256 i = 0; i < _debtTokens.length; i++) {
                _tradeAmounts[i] = (IERC20(_debtTokens[i]).balanceOf(address(this)));
                console.log(_tradeAmounts[i]);
            }
        } else {
            for (uint256 i = 0; i < _tradeAssets.length; i++) {
                /* @audit-ok
                attacker can send a small amount of trade assets here such the repay fails
                -> front-running
                repay does not fail, the remaining debt is paid -> see Aave Source code
                */
                /* @audit-ok
                what if there is a stable and a variable debt?
                both assets will be the same and for both the amount will be the whole balance
                which is not possible
                but the user can just partially close one kind of debt and then partially close the other kind of debt
                so it's just a usability issue

                would need multiple transactions but this is not a good solution
                -> time delay between transactions possible
                -> should be possible within one transaction

                should be possible to execute this in one transaction to avoid slippage
                partial closure should be possible within a single transaction (if necessary multiple flash loans but within the same transaction)
                
                it's not an issue that there might be multiple transactions necessary to close a position
                a complex position might require multiple transactions to be repaid

                maybe I can make a case that debt is not repaid as intended
                500 USDC stable debt
                500 USDC variable debt

                wanting to close 250 USDC of both
                so trading for 500 USDC
                both trying to repay 500 USDC
                transaction will fail

                the user can just do two transactions with 250 USDC each
                */
                /* @audit-ok
                that's not the traded amount this is using everything
                also the funds that should be left alone
                ; reported
                */
                _tradeAmounts[i] = (IERC20(_tradeAssets[i]).balanceOf(address(this)));
                console.log(_tradeAmounts[i]);
            }
        }
        for (uint256 i = 0; i < _tradeAssets.length; i++) {
            _lendingPoolRepay(_tradeAssets[i], _tradeAmounts[i], _rateMode[i], 1);
        }
        for (uint256 i = 0; i < _withdrawAssets.length; i++) {
            _lendingPoolWithdraw(_withdrawAssets[i], _withdrawAmounts[i], 1);
            // @audit-info this approve is needed to pay back the flash loan
            /* @audit-ok
            should approve the whole balance because withdrawn amount might not be sufficient to pay back the flash loan
            so user supplies extra balance
            or does it actually work?
            there are a number of ways to mitigate this scenario
            and why, if anything, this is a very rare edge case
            user could just deposit the balance into aave so it can then be withdrawn
            */
            IERC20(_withdrawAssets[i]).approve(address(lendingPool), _withdrawAmounts[i]);
        }
        uint256[] memory _returnAmounts = new uint256[](_tradeAssets.length);
        if (_flag == 2) {
            //Withdraw to user
            /* @audit-info
            sending excess debt tokens to the user
            doing a refund
            */
            /* @audit-ok
            cannot fully close a trade when a withdrawn asset is the same as a flash loaned asset
            because the amount to repay the flash loan will be transferred out
            BUT:
            1) it does not make sense to have a deposit in Asset A and at the same time have debt in Asset A, there's no point to do so
            2) User can just do multiple transactions to close the position, or do partial close instead.
            So that would just be an inconvenience for the user but no loss of funds or other issue
            */
            for (uint256 i = 0; i < _tradeAssets.length; i++) {
                _returnAmounts[i] = IERC20(_tradeAssets[i]).balanceOf(address(this));
                if (address(WETH) == _tradeAssets[i]) {
                    WETH.withdraw(_returnAmounts[i]);
                    _safeTransferETH(_USER, _returnAmounts[i]);
                } else {
                    IERC20(_tradeAssets[i]).transfer(_USER, _returnAmounts[i]);
                }
            }
        }
        emit ClosePosition(
            _flag,
            _swapAddress,
            _swapApproveToken,
            _tradeAssets,
            _tradeAmounts,
            _withdrawAssets,
            _withdrawAmounts,
            _rateMode,
            _returnAmounts
            );
    }

    /// @notice Withdraws the token from the lending pool
    /// @dev Token authorization, then withdraw from lendingPool.
    /// @param _asset Asset token address
    /// @param _amount Asset token Amount
    /// @param _flag Operation flag
    function _lendingPoolWithdraw(address _asset, uint256 _amount, uint8 _flag) internal {
        /* @audit-ok
        why calling approve here?
        it's not necessary, but it's not an issue if the approval is made here
        */
        _approveToken(address(lendingPool), _asset, _amount);
        lendingPool.withdraw(_asset, _amount, address(this));
        emit LendingPoolWithdraw(_asset, _amount, _flag);
    }

    /// @notice Deposits the token liquidity onto the lending pool as collateral
    /// @dev Token authorization, then deposits to lendingPool.
    /// @param _asset Asset token address
    /// @param _amount Asset token Amount
    /// @param _flag Operation flag
    // @audit-ok
    function _lendingPoolDeposit(address _asset, uint256 _amount, uint8 _flag) internal {
        _approveToken(address(lendingPool), _asset, _amount);
        lendingPool.deposit(_asset, _amount, address(this), Types.REFERRAL_CODE);
        emit LendingPoolDeposit(_asset, _amount, _flag);
    }

    /// @notice Repays a borrowed `amount` on a specific reserve, burning the equivalent debt tokens owned
    /// @param _repayAsset Repay asset token address
    /// @param _repayAmt Repay Asset token Amount
    /// @param _rateMode Rate mode 1: stable mode debt, 2: variable mode debt
    /// @param _flag Operation flag
    // @audit-ok
    function _lendingPoolRepay(address _repayAsset, uint256 _repayAmt, uint256 _rateMode, uint8 _flag) internal {
        // approve the repayment from this contract
        _approveToken(address(lendingPool), _repayAsset, _repayAmt);
        lendingPool.repay(_repayAsset, _repayAmt, _rateMode, address(this));
        emit LendingPoolRepay(_repayAsset, _repayAmt, _rateMode, _flag);
    }

    // @audit-ok
    function _approveToken(address _address, address _tokenAddress, uint256 _tokenAmount) internal {
        if (IERC20(_tokenAddress).allowance(address(this), _address) < _tokenAmount) {
            /* @audit-ok
            for the supported tokens, does 0 amount have to be approved first?
            check for all supported tokens on both chains
            is there wrapped MATIC?
            for the tokens that this protocol works with the approvals are not an issue
            */
            IERC20(_tokenAddress).approve(_address, type(uint256).max);
        }
    }

    /**
     * @dev transfer ETH to an address, revert if it fails.
     * @param to recipient of the transfer
     * @param value the amount to send
     */
     // @audit-ok
    function _safeTransferETH(address to, uint256 value) internal {
        (bool success,) = to.call{value: value}(new bytes(0));
        require(success, "ETH_TRANSFER_FAILED");
    }
}
