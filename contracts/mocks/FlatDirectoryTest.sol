// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "../FlatDirectory.sol";

contract FlatDirectoryTest is FlatDirectory {
    constructor(uint8 slotLimit, uint32 maxChunkSize, address storageAddress) FlatDirectory(slotLimit, maxChunkSize, storageAddress) {}

    function readNonView(bytes memory name) public view returns (bytes memory, bool) {
        return _get(keccak256(name));
    }

    function readManual(bytes memory name) external view returns (bytes memory) {
        (bytes memory content, ) = _get(keccak256(name));
        StorageHelper.returnBytesInplace(content);
    }
}
