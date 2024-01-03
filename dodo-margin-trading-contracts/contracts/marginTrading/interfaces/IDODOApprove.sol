// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.15;

interface IDODOApprove {
    function claimTokens(address token, address who, address dest, uint256 amount) external;
    function getDODOProxy() external view returns (address);
}
