/*

    Copyright 2020 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.7.6;

import {SafeMath} from "../../lib/SafeMath.sol";
import {IERC20} from "../../intf/IERC20.sol";
import {SafeERC20} from "../../lib/SafeERC20.sol";

library UniversalERC20 {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    function universalTransfer(
        IERC20 token,
        address payable to,
        uint256 amount
    ) internal {
        if (amount > 0) {
            token.safeTransfer(to, amount);
        }
    }

    function universalApproveMax(
        IERC20 token,
        address to,
        uint256 amount
    ) internal {
        uint256 allowance = token.allowance(address(this), to);
        if (allowance < amount) {
            if (allowance > 0) {
                token.safeApprove(to, 0);
            }
            token.safeApprove(to, uint256(-1));
        }
    }
}
