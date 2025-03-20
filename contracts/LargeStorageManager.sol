// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./optimize/SlotHelper.sol";
import "./StorageHelper.sol";
import "./StorageSlotSelfDestructable.sol";

// Large storage manager to support arbitrarily-sized data with multiple chunk
contract LargeStorageManager {
    using SlotHelper for bytes32;
    using SlotHelper for address;

    uint8 internal immutable SLOT_LIMIT;

    mapping(bytes32 => mapping(uint256 => bytes32)) internal keyToMetadata;
    mapping(bytes32 => mapping(uint256 => mapping(uint256 => bytes32))) internal keyToSlots;
    mapping(bytes32 => uint256) private keyToChunkNum;
    mapping(bytes32 => uint256) private keyToTotalSize;

    constructor(uint8 slotLimit) {
        SLOT_LIMIT = slotLimit;
    }

    function isOptimize() public view returns (bool) {
        return SLOT_LIMIT > 0;
    }

    function _preparePut(bytes32 key, uint256 chunkId, uint256 newSize) private {
        bytes32 metadata = keyToMetadata[key][chunkId];
        if (metadata == bytes32(0)) {
            require(chunkId == 0 || keyToMetadata[key][chunkId - 1] != bytes32(0x0), "must replace or append");
            keyToChunkNum[key]++;
        } else {
            (uint256 oldSize, ) = _chunkSize(key, chunkId);
            keyToTotalSize[key] -= oldSize;
        }
        keyToTotalSize[key] += newSize;

        if (!metadata.isInSlot()) {
            address addr = metadata.bytes32ToAddr();
            if (addr != address(0x0)) {
                // remove the KV first if it exists
                StorageSlotSelfDestructable(addr).destruct();
            }
        }
    }

    function _putChunkFromCalldata(
        bytes32 key,
        uint256 chunkId,
        bytes calldata data,
        uint256 value
    ) internal {
        _preparePut(key, chunkId, data.length);

        // store data and rewrite metadata
        if (data.length > SLOT_LIMIT) {
            keyToMetadata[key][chunkId] = StorageHelper.putRawFromCalldata(data, value).addrToBytes32();
        } else {
            keyToMetadata[key][chunkId] = SlotHelper.putRaw(keyToSlots[key][chunkId], data);
        }
    }

    function _putChunk(
        bytes32 key,
        uint256 chunkId,
        bytes memory data,
        uint256 value
    ) internal {
        _preparePut(key, chunkId, data.length);

        // store data and rewrite metadata
        if (data.length > SLOT_LIMIT) {
            keyToMetadata[key][chunkId] = StorageHelper.putRaw(data, value).addrToBytes32();
        } else {
            keyToMetadata[key][chunkId] = SlotHelper.putRaw(keyToSlots[key][chunkId], data);
        }
    }

    function _getChunk(bytes32 key, uint256 chunkId) internal view returns (bytes memory, bool) {
        bytes32 metadata = keyToMetadata[key][chunkId];

        if (metadata.isInSlot()) {
            return (SlotHelper.getRaw(keyToSlots[key][chunkId], metadata), true);
        } else {
            return StorageHelper.getRaw(metadata.bytes32ToAddr());
        }
    }

    function _chunkSize(bytes32 key, uint256 chunkId) internal view returns (uint256, bool) {
        bytes32 metadata = keyToMetadata[key][chunkId];

        if (metadata == bytes32(0)) {
            return (0, false);
        } else if (metadata.isInSlot()) {
            return (metadata.decodeLen(), true);
        } else {
            return StorageHelper.sizeRaw(metadata.bytes32ToAddr());
        }
    }

    function _countChunks(bytes32 key) internal view returns (uint256) {
        return keyToChunkNum[key];
    }

    // Returns (size, # of chunks).
    function _size(bytes32 key) internal view returns (uint256, uint256) {
        return (keyToTotalSize[key], keyToChunkNum[key]);
    }

    function _get(bytes32 key) internal view returns (bytes memory, bool) {
        (uint256 size, uint256 chunkNum) = _size(key);
        if (chunkNum == 0) {
            return (new bytes(0), false);
        }

        bytes memory data = new bytes(size); // solidity should auto-align the memory-size to 32
        uint256 dataPtr;
        assembly {
            dataPtr := add(data, 0x20)
        }
        for (uint256 chunkId = 0; chunkId < chunkNum; chunkId++) {
            bytes32 metadata = keyToMetadata[key][chunkId];

            uint256 chunkSize = 0;
            if (metadata.isInSlot()) {
                chunkSize = metadata.decodeLen();
                SlotHelper.getRawAt(keyToSlots[key][chunkId], metadata, dataPtr);
            } else {
                address addr = metadata.bytes32ToAddr();
                (chunkSize, ) = StorageHelper.sizeRaw(addr);
                StorageHelper.getRawAt(addr, dataPtr);
            }

            dataPtr += chunkSize;
        }

        return (data, true);
    }

    // Returns # of chunks deleted
    function _remove(bytes32 key, uint256 chunkId) internal returns (uint256) {
        while (keyToMetadata[key][chunkId] != bytes32(0)) {
            bytes32 metadata = keyToMetadata[key][chunkId];

            if (!metadata.isInSlot()) {
                address addr = metadata.bytes32ToAddr();
                (uint256 chunkSize, ) = StorageHelper.sizeRaw(addr);
                keyToTotalSize[key] -= chunkSize;
                // remove new contract
                StorageSlotSelfDestructable(addr).destruct();
            } else {
                keyToTotalSize[key] -= metadata.decodeLen();
            }

            keyToMetadata[key][chunkId] = bytes32(0x0);
            keyToChunkNum[key]--;

            chunkId++;
        }

        return chunkId;
    }

    function _removeChunk(bytes32 key, uint256 chunkId) internal returns (bool) {
        if (chunkId != keyToChunkNum[key] - 1) {
            return false;
        }
        bytes32 metadata = keyToMetadata[key][chunkId];
        if (!metadata.isInSlot()) {
            address addr = metadata.bytes32ToAddr();
            (uint256 chunkSize, ) = StorageHelper.sizeRaw(addr);
            keyToTotalSize[key] -= chunkSize;
            // remove new contract
            StorageSlotSelfDestructable(addr).destruct();
        } else {
            keyToTotalSize[key] -= metadata.decodeLen();
        }

        keyToMetadata[key][chunkId] = bytes32(0x0);
        keyToChunkNum[key]--;

        return true;
    }
}
