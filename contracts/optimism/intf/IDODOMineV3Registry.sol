/*
    Copyright 2021 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0
*/

pragma solidity 0.7.6;

interface IDODOMineV3Registry {
    function addMineV3(
        address mine,
        bool isLpToken,
        address stakeToken
    ) external;
}
