/*

    Copyright 2020 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.7.6;

interface IDODOApproveProxy {
    function isAllowedProxy(address _proxy) external view returns (bool);
    function claimTokens(address token,address who,address dest,uint256 amount) external;
}
