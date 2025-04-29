// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Create a storage slot
contract StorageSlotFactoryFromInput {
    constructor(bytes memory codeAndData) {
        uint256 size = codeAndData.length;
        // Return the contract manually
        assembly {
            return(add(codeAndData, 0x20), size)
        }
    }
}
