/*

    Copyright 2020 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.7.6;

interface IDODONFTRegistry {
    function addRegistry(
        address vault,
        address fragment, 
        address quoteToken,
        address dvm
    ) external;

    function removeRegistry(address fragment) external;
}
