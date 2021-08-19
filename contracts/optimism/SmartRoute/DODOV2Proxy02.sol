/*

    Copyright 2020 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.7.6;

import {IDODOV2} from "./intf/IDODOV2.sol";
import {IERC20} from "../intf/IERC20.sol";
import {SafeMath} from "../lib/SafeMath.sol";
import {UniversalERC20} from "./lib/UniversalERC20.sol";
import {SafeERC20} from "../lib/SafeERC20.sol";
import {DecimalMath} from "../lib/DecimalMath.sol";
import {ReentrancyGuard} from "../lib/ReentrancyGuard.sol";
import {InitializableOwnable} from "../lib/InitializableOwnable.sol";
import {IDODOAdapter} from "./intf/IDODOAdapter.sol";
import {IDODOSellHelper} from "./intf/IDODOSellHelper.sol";
import {IDODOApproveProxy} from "./intf/IDODOApproveProxy.sol";
// import {IDODOV1} from "./intf/IDODOV1.sol";

interface IDODOV1 {
    function sellBaseToken(
        uint256 amount,
        uint256 minReceiveQuote,
        bytes calldata data
    ) external returns (uint256);
    function buyBaseToken(
        uint256 amount,
        uint256 maxPayQuote,
        bytes calldata data
    ) external returns (uint256);
    function depositBaseTo(address to, uint256 amount) external returns (uint256);
    function depositQuoteTo(address to, uint256 amount) external returns (uint256);
    function _BASE_TOKEN_() external view returns (address);
    function _QUOTE_TOKEN_() external view returns (address);
}

/**
 * @title DODOV2Proxy02
 * @author DODO Breeder
 *
 * @notice Entrance of trading in DODO platform
 */
contract DODOV2Proxy02 is ReentrancyGuard, InitializableOwnable {
    using SafeMath for uint256;
    using UniversalERC20 for IERC20;

    // ============ Storage ============

    address constant _ETH_ = 0x4200000000000000000000000000000000000006;
    address public immutable _DODO_APPROVE_PROXY_;
    address public immutable _DODO_SELL_HELPER_;
    address public immutable _DVM_FACTORY_;
    address public immutable _DPP_FACTORY_;
    mapping (address => bool) public isWhiteListed;

    // ============ Events ============

    event OrderHistory(
        address fromToken,
        address toToken,
        address sender,
        uint256 fromAmount,
        uint256 returnAmount
    );

    // ============ Modifiers ============

    modifier judgeExpired(uint256 deadLine) {
        require(deadLine >= block.timestamp, "EXPIRED");
        _;
    }

    fallback() external payable {}

    receive() external payable {}

    constructor(
        address dvmFactory,
        address dppFactory,
        address dodoApproveProxy,
        address dodoSellHelper
    ) {
        _DVM_FACTORY_ = dvmFactory;
        _DPP_FACTORY_ = dppFactory;
        _DODO_APPROVE_PROXY_ = dodoApproveProxy;
        _DODO_SELL_HELPER_ = dodoSellHelper;
    }

    function addWhiteList (address contractAddr) public onlyOwner {
        isWhiteListed[contractAddr] = true;
    }

    function removeWhiteList (address contractAddr) public onlyOwner {
        isWhiteListed[contractAddr] = false;
    }

    // ============ DVM Functions (create & add liquidity) ============

    function createDODOVendingMachine(
        address baseToken,
        address quoteToken,
        uint256 baseInAmount,
        uint256 quoteInAmount,
        uint256 lpFeeRate,
        uint256 i,
        uint256 k,
        bool isOpenTWAP,
        uint256 deadLine
    )
        external
        payable
        preventReentrant
        judgeExpired(deadLine)
        returns (address newVendingMachine, uint256 shares)
    {
        {
            address _baseToken = baseToken;
            address _quoteToken = quoteToken;
            newVendingMachine = IDODOV2(_DVM_FACTORY_).createDODOVendingMachine(
                msg.sender,
                _baseToken,
                _quoteToken,
                lpFeeRate,
                i,
                k,
                isOpenTWAP
            );
        }

        {
            address _baseToken = baseToken;
            address _quoteToken = quoteToken;
            _deposit(
                msg.sender,
                newVendingMachine,
                _baseToken,
                baseInAmount,
                _baseToken == _ETH_
            );
            _deposit(
                msg.sender,
                newVendingMachine,
                _quoteToken,
                quoteInAmount,
                _quoteToken == _ETH_
            );
        }

        (shares, , ) = IDODOV2(newVendingMachine).buyShares(msg.sender);
    }

    function addDVMLiquidity(
        address dvmAddress,
        uint256 baseInAmount,
        uint256 quoteInAmount,
        uint256 baseMinAmount,
        uint256 quoteMinAmount,
        uint8 flag, // 0 - ERC20, 1 - baseInETH, 2 - quoteInETH
        uint256 deadLine
    )
        external
        payable
        preventReentrant
        judgeExpired(deadLine)
        returns (
            uint256 shares,
            uint256 baseAdjustedInAmount,
            uint256 quoteAdjustedInAmount
        )
    {
        address _dvm = dvmAddress;
        (baseAdjustedInAmount, quoteAdjustedInAmount) = _addDVMLiquidity(
            _dvm,
            baseInAmount,
            quoteInAmount
        );

        require(
            baseAdjustedInAmount >= baseMinAmount && quoteAdjustedInAmount >= quoteMinAmount,
            "deposit amount is not enough"
        );

        _deposit(msg.sender, _dvm, IDODOV2(_dvm)._BASE_TOKEN_(), baseAdjustedInAmount, flag == 1);
        _deposit(msg.sender, _dvm, IDODOV2(_dvm)._QUOTE_TOKEN_(), quoteAdjustedInAmount, flag == 2);
        
        (shares, , ) = IDODOV2(_dvm).buyShares(msg.sender);
        // refund dust eth
        if (flag == 1 && baseInAmount > baseAdjustedInAmount) IERC20(_ETH_).transfer(msg.sender, baseInAmount - baseAdjustedInAmount);
        if (flag == 2 && quoteInAmount > quoteAdjustedInAmount) IERC20(_ETH_).transfer(msg.sender, quoteInAmount - quoteAdjustedInAmount);
    }

    function _addDVMLiquidity(
        address dvmAddress,
        uint256 baseInAmount,
        uint256 quoteInAmount
    ) internal view returns (uint256 baseAdjustedInAmount, uint256 quoteAdjustedInAmount) {
        (uint256 baseReserve, uint256 quoteReserve) = IDODOV2(dvmAddress).getVaultReserve();
        if (quoteReserve == 0 && baseReserve == 0) {
            baseAdjustedInAmount = baseInAmount;
            quoteAdjustedInAmount = quoteInAmount;
        }
        if (quoteReserve == 0 && baseReserve > 0) {
            baseAdjustedInAmount = baseInAmount;
            quoteAdjustedInAmount = 0;
        }
        if (quoteReserve > 0 && baseReserve > 0) {
            uint256 baseIncreaseRatio = DecimalMath.divFloor(baseInAmount, baseReserve);
            uint256 quoteIncreaseRatio = DecimalMath.divFloor(quoteInAmount, quoteReserve);
            if (baseIncreaseRatio <= quoteIncreaseRatio) {
                baseAdjustedInAmount = baseInAmount;
                quoteAdjustedInAmount = DecimalMath.mulFloor(quoteReserve, baseIncreaseRatio);
            } else {
                quoteAdjustedInAmount = quoteInAmount;
                baseAdjustedInAmount = DecimalMath.mulFloor(baseReserve, quoteIncreaseRatio);
            }
        }
    }

    // ============ DPP Functions (create & reset) ============

    function createDODOPrivatePool(
        address baseToken,
        address quoteToken,
        uint256 baseInAmount,
        uint256 quoteInAmount,
        uint256 lpFeeRate,
        uint256 i,
        uint256 k,
        bool isOpenTwap,
        uint256 deadLine
    )
        external
        payable
        preventReentrant
        judgeExpired(deadLine)
        returns (address newPrivatePool)
    {
        newPrivatePool = IDODOV2(_DPP_FACTORY_).createDODOPrivatePool();

        address _baseToken = baseToken;
        address _quoteToken = quoteToken;
        _deposit(msg.sender, newPrivatePool, _baseToken, baseInAmount, _baseToken == _ETH_);
        _deposit(
            msg.sender,
            newPrivatePool,
            _quoteToken,
            quoteInAmount,
            _quoteToken == _ETH_
        );

        IDODOV2(_DPP_FACTORY_).initDODOPrivatePool(
            newPrivatePool,
            msg.sender,
            _baseToken,
            _quoteToken,
            lpFeeRate,
            k,
            i,
            isOpenTwap
        );
    }

    function resetDODOPrivatePool(
        address dppAddress,
        uint256[] memory paramList,  //0 - newLpFeeRate, 1 - newI, 2 - newK
        uint256[] memory amountList, //0 - baseInAmount, 1 - quoteInAmount, 2 - baseOutAmount, 3- quoteOutAmount
        uint8 flag, // 0 - ERC20, 1 - baseInETH, 2 - quoteInETH, 3 - baseOutETH, 4 - quoteOutETH
        uint256 minBaseReserve,
        uint256 minQuoteReserve,
        uint256 deadLine
    ) external payable preventReentrant judgeExpired(deadLine) {
        _deposit(
            msg.sender,
            dppAddress,
            IDODOV2(dppAddress)._BASE_TOKEN_(),
            amountList[0],
            flag == 1
        );
        _deposit(
            msg.sender,
            dppAddress,
            IDODOV2(dppAddress)._QUOTE_TOKEN_(),
            amountList[1],
            flag == 2
        );

        require(IDODOV2(IDODOV2(dppAddress)._OWNER_()).reset(
            msg.sender,
            paramList[0],
            paramList[1],
            paramList[2],
            amountList[2],
            amountList[3],
            minBaseReserve,
            minQuoteReserve
        ), "Reset Failed");
    }

    // ============ Swap ============

    function dodoSwapV2ETHToToken(
        address toToken,
        uint256 minReturnAmount,
        address[] memory dodoPairs,
        uint256 directions,
        bool,
        uint256 deadLine
    )
        external
        payable
        judgeExpired(deadLine)
        returns (uint256 returnAmount)
    {
        require(dodoPairs.length > 0, "PAIRS_EMPTY");
        require(minReturnAmount > 0, "RETURN_AMOUNT_ZERO");
        
        uint256 originToTokenBalance = IERC20(toToken).balanceOf(msg.sender);

        uint256 msgValue = IERC20(_ETH_).balanceOf(address(this));
        IERC20(_ETH_).transfer(dodoPairs[0], msgValue);

        for (uint256 i = 0; i < dodoPairs.length; i++) {
            if (i == dodoPairs.length - 1) {
                if (directions & 1 == 0) {
                    IDODOV2(dodoPairs[i]).sellBase(msg.sender);
                } else {
                    IDODOV2(dodoPairs[i]).sellQuote(msg.sender);
                }
            } else {
                if (directions & 1 == 0) {
                    IDODOV2(dodoPairs[i]).sellBase(dodoPairs[i + 1]);
                } else {
                    IDODOV2(dodoPairs[i]).sellQuote(dodoPairs[i + 1]);
                }
            }
            directions = directions >> 1;
        }

        returnAmount = IERC20(toToken).balanceOf(msg.sender).sub(originToTokenBalance);
        require(returnAmount >= minReturnAmount, "Return amount is not enough");

        emit OrderHistory(
            _ETH_,
            toToken,
            msg.sender,
            msgValue,
            returnAmount
        );
    }

    function dodoSwapV2TokenToETH(
        address fromToken,
        uint256 fromTokenAmount,
        uint256 minReturnAmount,
        address[] memory dodoPairs,
        uint256 directions,
        bool,
        uint256 deadLine
    )
        external
        judgeExpired(deadLine)
        returns (uint256 returnAmount)
    {
        require(dodoPairs.length > 0, "PAIRS_EMPTY");
        require(minReturnAmount > 0, "RETURN_AMOUNT_ZERO");
        
        IDODOApproveProxy(_DODO_APPROVE_PROXY_).claimTokens(fromToken, msg.sender, dodoPairs[0], fromTokenAmount);

        for (uint256 i = 0; i < dodoPairs.length; i++) {
            if (i == dodoPairs.length - 1) {
                if (directions & 1 == 0) {
                    IDODOV2(dodoPairs[i]).sellBase(address(this));
                } else {
                    IDODOV2(dodoPairs[i]).sellQuote(address(this));
                }
            } else {
                if (directions & 1 == 0) {
                    IDODOV2(dodoPairs[i]).sellBase(dodoPairs[i + 1]);
                } else {
                    IDODOV2(dodoPairs[i]).sellQuote(dodoPairs[i + 1]);
                }
            }
            directions = directions >> 1;
        }
        returnAmount = IERC20(_ETH_).balanceOf(address(this));
        require(returnAmount >= minReturnAmount, "Return amount is not enough");
        IERC20(_ETH_).transfer(msg.sender, returnAmount);

        emit OrderHistory(
            fromToken,
            _ETH_,
            msg.sender,
            fromTokenAmount,
            returnAmount
        );
    }

    function dodoSwapV2TokenToToken(
        address fromToken,
        address toToken,
        uint256 fromTokenAmount,
        uint256 minReturnAmount,
        address[] memory dodoPairs,
        uint256 directions,
        bool,
        uint256 deadLine
    )
        external
        judgeExpired(deadLine)
        returns (uint256 returnAmount)
    {
        require(dodoPairs.length > 0, "PAIRS_EMPTY");
        require(minReturnAmount > 0, "RETURN_AMOUNT_ZERO");

        uint256 originToTokenBalance = IERC20(toToken).balanceOf(msg.sender);
        IDODOApproveProxy(_DODO_APPROVE_PROXY_).claimTokens(fromToken, msg.sender, dodoPairs[0], fromTokenAmount);

        for (uint256 i = 0; i < dodoPairs.length; i++) {
            if (i == dodoPairs.length - 1) {
                if (directions & 1 == 0) {
                    IDODOV2(dodoPairs[i]).sellBase(msg.sender);
                } else {
                    IDODOV2(dodoPairs[i]).sellQuote(msg.sender);
                }
            } else {
                if (directions& 1 == 0) {
                    IDODOV2(dodoPairs[i]).sellBase(dodoPairs[i + 1]);
                } else {
                    IDODOV2(dodoPairs[i]).sellQuote(dodoPairs[i + 1]);
                }
            }
            directions = directions >> 1;
        }
        returnAmount = IERC20(toToken).balanceOf(msg.sender).sub(originToTokenBalance);
        require(returnAmount >= minReturnAmount, "Return amount is not enough");

        emit OrderHistory(
            fromToken,
            toToken,
            msg.sender,
            fromTokenAmount,
            returnAmount
        );
    }

    function externalSwap(
        address fromToken,
        address toToken,
        address approveTarget,
        address swapTarget,
        uint256 fromTokenAmount,
        uint256 minReturnAmount,
        bytes memory callDataConcat,
        bool,
        uint256 deadLine
    )
        external
        payable
        judgeExpired(deadLine)
        returns (uint256 returnAmount)
    {
        require(minReturnAmount > 0, "RETURN_AMOUNT_ZERO");

        address _fromToken = fromToken;
        address _toToken = toToken;
        
        uint256 toTokenOriginBalance = IERC20(_toToken).balanceOf(msg.sender);

        if (_fromToken != _ETH_) {
            IDODOApproveProxy(_DODO_APPROVE_PROXY_).claimTokens(
                _fromToken,
                msg.sender,
                address(this),
                fromTokenAmount
            );
            IERC20(_fromToken).universalApproveMax(approveTarget, fromTokenAmount);
        } else {
            uint256 msgValue = IERC20(_ETH_).balanceOf(address(this));
            IERC20(_ETH_).transfer(swapTarget, msgValue);
        }

        require(isWhiteListed[swapTarget], "Not Whitelist Contract");        
        (bool success, ) = swapTarget.call(callDataConcat);
        require(success, "External Swap execution Failed");

        IERC20(_toToken).universalTransfer(
            msg.sender,
            IERC20(_toToken).balanceOf(address(this))
        );

        returnAmount = IERC20(_toToken).balanceOf(msg.sender).sub(toTokenOriginBalance);
        require(returnAmount >= minReturnAmount, "Return amount is not enough");

        emit OrderHistory(
            _fromToken,
            _toToken,
            msg.sender,
            fromTokenAmount,
            returnAmount
        );
    }

    function dodoSwapV1(
        address fromToken,
        address toToken,
        uint256 fromTokenAmount,
        uint256 minReturnAmount,
        address[] memory dodoPairs,
        uint256 directions,
        bool,
        uint256 deadLine
    )
        external
        payable
        judgeExpired(deadLine)
        returns (uint256 returnAmount)
    {
        require(dodoPairs.length > 0, "PAIRS_EMPTY");
        require(minReturnAmount > 0, "RETURN_AMOUNT_ZERO");
        

        address _fromToken = fromToken;
        address _toToken = toToken;

        _deposit(msg.sender, address(this), _fromToken, fromTokenAmount, _fromToken == _ETH_);

        for (uint256 i = 0; i < dodoPairs.length; i++) {
            address curDodoPair = dodoPairs[i];
            if (directions & 1 == 0) {
                address curDodoBase = IDODOV1(curDodoPair)._BASE_TOKEN_();
                uint256 curAmountIn = IERC20(curDodoBase).balanceOf(address(this));
                IERC20(curDodoBase).universalApproveMax(curDodoPair, curAmountIn);
                IDODOV1(curDodoPair).sellBaseToken(curAmountIn, 0, "");
            } else {
                address curDodoQuote = IDODOV1(curDodoPair)._QUOTE_TOKEN_();
                uint256 curAmountIn = IERC20(curDodoQuote).balanceOf(address(this));
                IERC20(curDodoQuote).universalApproveMax(curDodoPair, curAmountIn);
                uint256 canBuyBaseAmount = IDODOSellHelper(_DODO_SELL_HELPER_).querySellQuoteToken(
                    curDodoPair,
                    curAmountIn
                );
                IDODOV1(curDodoPair).buyBaseToken(canBuyBaseAmount, curAmountIn, "");
            }
            directions = directions >> 1;
        }

        returnAmount = IERC20(_toToken).balanceOf(address(this));
        
        require(returnAmount >= minReturnAmount, "Return amount is not enough");
        IERC20(_toToken).universalTransfer(msg.sender, returnAmount);

        emit OrderHistory(_fromToken, _toToken, msg.sender, fromTokenAmount, returnAmount);
    }


    function mixSwap(
        address fromToken,
        address toToken,
        uint256 fromTokenAmount,
        uint256 minReturnAmount,
        address[] memory mixAdapters,
        address[] memory mixPairs,
        address[] memory assetTo,
        uint256 directions,
        bool,
        uint256 deadLine
    ) external payable judgeExpired(deadLine) returns (uint256 returnAmount) {
        require(mixPairs.length > 0, "PAIRS_EMPTY");
        require(mixPairs.length == mixAdapters.length, "PAIR_ADAPTER_NOT_MATCH");
        require(mixPairs.length == assetTo.length - 1, "PAIR_ASSETTO_NOT_MATCH");
        require(minReturnAmount > 0, "RETURN_AMOUNT_ZERO");

        address _fromToken = fromToken;
        address _toToken = toToken;
        uint256 _fromTokenAmount = fromTokenAmount;
        
        uint256 toTokenOriginBalance = IERC20(_toToken).balanceOf(msg.sender);
        
        _deposit(msg.sender, assetTo[0], _fromToken, _fromTokenAmount, _fromToken == _ETH_);

        for (uint256 i = 0; i < mixPairs.length; i++) {
            if (directions & 1 == 0) {
                IDODOAdapter(mixAdapters[i]).sellBase(assetTo[i + 1],mixPairs[i], "");
            } else {
                IDODOAdapter(mixAdapters[i]).sellQuote(assetTo[i + 1],mixPairs[i], "");
            }
            directions = directions >> 1;
        }

        if(_toToken == _ETH_) {
            returnAmount = IERC20(_ETH_).balanceOf(address(this));
            IERC20(_ETH_).transfer(msg.sender,returnAmount);
        }else {
            returnAmount = IERC20(_toToken).balanceOf(msg.sender).sub(toTokenOriginBalance);
        }

        require(returnAmount >= minReturnAmount, "Return amount is not enough");

        emit OrderHistory(
            _fromToken,
            _toToken,
            msg.sender,
            _fromTokenAmount,
            returnAmount
        );
    }

    //============ CrowdPooling Functions (bid) ============
    function bid(
        address cpAddress,
        uint256 quoteAmount,
        uint8 flag, // 0 - ERC20, 1 - quoteInETH
        uint256 deadLine
    ) external payable preventReentrant judgeExpired(deadLine) {
        _deposit(msg.sender, cpAddress, IDODOV2(cpAddress)._QUOTE_TOKEN_(), quoteAmount, flag == 1);
        IDODOV2(cpAddress).bid(msg.sender);
    }


    function addLiquidityToV1(
        address pair,
        uint256 baseAmount,
        uint256 quoteAmount,
        uint256 baseMinShares,
        uint256 quoteMinShares,
        uint8 flag, // 0 erc20 In  1 baseInETH  2 quoteIn ETH 
        uint256 deadLine
    ) external payable preventReentrant judgeExpired(deadLine) returns(uint256 baseShares, uint256 quoteShares) {
        address _baseToken = IDODOV1(pair)._BASE_TOKEN_();
        address _quoteToken = IDODOV1(pair)._QUOTE_TOKEN_();
        
        _deposit(msg.sender, address(this), _baseToken, baseAmount, flag == 1);
        _deposit(msg.sender, address(this), _quoteToken, quoteAmount, flag == 2);

        
        if(baseAmount > 0) {
            IERC20(_baseToken).universalApproveMax(pair, baseAmount);
            baseShares = IDODOV1(pair).depositBaseTo(msg.sender, baseAmount);
        }
        if(quoteAmount > 0) {
            IERC20(_quoteToken).universalApproveMax(pair, quoteAmount);
            quoteShares = IDODOV1(pair).depositQuoteTo(msg.sender, quoteAmount);
        }

        require(baseShares >= baseMinShares && quoteShares >= quoteMinShares,"Return DLP is not enough");
    }
    

    function _deposit(
        address from,
        address to,
        address token,
        uint256 amount,
        bool isETH
    ) internal {
        if (isETH) {
            if (amount > 0) {
                if (to != address(this)) SafeERC20.safeTransfer(IERC20(_ETH_), to, amount);
            }
        } else {
            IDODOApproveProxy(_DODO_APPROVE_PROXY_).claimTokens(token, from, to, amount);
        }
    }
}
