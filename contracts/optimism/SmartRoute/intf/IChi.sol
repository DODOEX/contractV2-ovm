pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

interface IChi {
    function freeUpTo(uint256 value) external returns (uint256);
}