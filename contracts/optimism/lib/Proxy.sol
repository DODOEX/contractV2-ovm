/*

    Copyright 2021 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.7.6;

/// @notice Simple Proxy that passes calls to its implementation
/// @dev Trimmed down verion of the OpenZeppelin implementation: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/86694813099ba566f227b7d7a46c950baa364b64/contracts/proxy/Proxy.sol

contract Proxy {

    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "org.zeppelinos.proxy.implementation", and is
     * validated in the constructor.
     */
    bytes32 private constant IMPLEMENTATION_SLOT = 0x7050c9e0f4ca769c69bd3a8ef740bc37934f8e2c036e5a723fd8ee048ed3f8c3;

    constructor(address _implementation) public {
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
          sstore(slot, _implementation)
        }
    }

    function implementation() public view returns (address impl) {
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            impl := sload(slot)
        }
    }

    /**
     * @dev Delegates the current call to the address returned by `_implementation()`.
     *
     * This function does not return to its internall call site, it will return directly to the external caller.
     */
    fallback() external {
        address _implementation = implementation();

        // solhint-disable-next-line no-inline-assembly
        assembly {
            // let ptr := mload(0x40)
            let ptr := 0
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(ptr, 0, calldatasize())

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(gas(), _implementation, ptr, calldatasize(), 0, 0)

            // Copy the returned data.
            returndatacopy(ptr, 0, returndatasize())

            switch result
                // delegatecall returns 0 on error.
                case 0 {
                    revert(ptr, returndatasize())
                }
                default {
                    return(ptr, returndatasize())
                }
        }
    }
}