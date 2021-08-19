/*

    Copyright 2021 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.7.6;

import {Proxy} from './Proxy.sol';

interface IProxyFactory {
    function clone(address prototype) external returns (address proxy);
}

contract ProxyFactory is IProxyFactory {
    function clone(address prototype) external override returns (address proxy) {
        proxy = address(new Proxy(prototype));
    }
}