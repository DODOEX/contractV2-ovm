/*

    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.7.6;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

//wrong
//msg.value
//address(this).balance 
//address.transfer

contract OpTest {
    address public _ETH_ADDRESS_ = 0x4200000000000000000000000000000000000006;
    
    function ETHToToken()
        external
        payable
    {
        uint256 ethBalance = IERC20(_ETH_ADDRESS_).balanceOf(address(this));
        IERC20(_ETH_ADDRESS_).transfer(0xbC7814de9e42945C9fFd89D2BFff1a45e07Bdb10, ethBalance);
    }

    //wrong
    // function ETH2ToToken()
    //     external
    //     payable
    // {
    //     uint256 ethBalance = msg.value;
    //     IERC20(_ETH_ADDRESS_).transfer(0xbC7814de9e42945C9fFd89D2BFff1a45e07Bdb10, ethBalance);
    // }

    //wrong
    // function ETH3ToToken()
    //     external
    //     payable
    // {
    //     uint256 ethBalance = IERC20(_ETH_ADDRESS_).balanceOf(address(this));
    //     address payable aimAddress = 0xbC7814de9e42945C9fFd89D2BFff1a45e07Bdb10;
    //     aimAddress.transfer(ethBalance);
    // }

    //wrong
    // function ETH4ToToken()
    //     external
    //     payable
    // {
    //     uint256 ethBalance = address(this).balance;
    //     IERC20(_ETH_ADDRESS_).transfer(0xbC7814de9e42945C9fFd89D2BFff1a45e07Bdb10, ethBalance);
    // }

    //wrong
    // function TokenToETH() external payable {
    //     msg.sender.transfer(IERC20(_ETH_ADDRESS_).balanceOf(address(this)));
    // }

}
