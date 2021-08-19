/*

    Copyright 2020 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.7.6;

interface IRewardVault {
    function reward(address to, uint256 amount) external;
    function withdrawLeftOver(address to, uint256 amount) external; 
    function syncValue() external;
    function _TOTAL_REWARD_() external view returns(uint256);
}