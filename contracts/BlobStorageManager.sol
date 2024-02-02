// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

enum DecodeType {
    RawData,
    PaddingPer31Bytes
}

interface EthStorageContract {
    function putBlob(bytes32 key, uint256 blobIdx, uint256 length) external payable;

    function get(bytes32 key, DecodeType decodeType, uint256 off, uint256 len) external view returns (bytes memory);

    function remove(bytes32 key) external;

    function hash(bytes32 key) external view returns (bytes24);

    function size(bytes32 key) external view returns (uint256);

    function upfrontPayment() external view returns (uint256);
}

contract BlobStorageManager is Ownable {

    uint32 public maxChunkSize;
    EthStorageContract public storageContract;
    mapping(bytes32 => mapping(uint256 => bytes32)) internal keyToChunks;

    constructor(uint32 size, address storageAddress) {
        maxChunkSize = size;
        storageContract = EthStorageContract(storageAddress);
    }

    function changeEsContract(address storageAddress) public onlyOwner {
        storageContract = EthStorageContract(storageAddress);
    }

    function changeMaxChunkSize(uint32 size) public onlyOwner {
        maxChunkSize = size;
    }

    function isSupportBlob() view public returns (bool) {
        return address(storageContract) != address(0) && upfrontPayment() >= 0;
    }

    function upfrontPayment() public view returns (uint256) {
        return storageContract.upfrontPayment();
    }

    function _countChunksFromBlob(bytes32 key) internal view returns (uint256) {
        uint256 chunkId = 0;
        while (true) {
            bytes32 chunkKey = keyToChunks[key][chunkId];
            if (chunkKey == bytes32(0)) {
                break;
            }
            chunkId++;
        }
        return chunkId;
    }

    function _chunkSizeFromBlob(bytes32 key, uint256 chunkId) internal view returns (uint256, bool) {
        if (chunkId >= _countChunksFromBlob(key)) {
            return (0, false);
        }
        uint256 length = storageContract.size(keyToChunks[key][chunkId]);
        return (length, true);
    }

    function _sizeFromBlob(bytes32 key) internal view returns (uint256, uint256) {
        uint256 chunkNum = _countChunksFromBlob(key);
        uint256 size = 0;
        for (uint256 chunkId = 0; chunkId < chunkNum; chunkId++) {
            size += storageContract.size(keyToChunks[key][chunkId]);
        }
        return (size, chunkNum);
    }

    function _getChunkFromBlob(bytes32 key, uint256 chunkId) internal view returns (bytes memory, bool) {
        (uint256 length,) = _chunkSizeFromBlob(key, chunkId);
        if (length < 1) {
            return (new bytes(0), false);
        }

        bytes memory data = storageContract.get(keyToChunks[key][chunkId], DecodeType.PaddingPer31Bytes, 0, length);
        return (data, true);
    }

    function _getFromBlob(bytes32 key) internal view returns (bytes memory, bool) {
        (uint256 fileSize, uint256 chunkNum) = _sizeFromBlob(key);
        if (chunkNum == 0) {
            return (new bytes(0), false);
        }

        bytes memory concatenatedData = new bytes(fileSize);
        uint256 offset = 0;
        for (uint256 chunkId = 0; chunkId < chunkNum; chunkId++) {
            bytes32 chunkKey = keyToChunks[key][chunkId];
            uint256 length = storageContract.size(chunkKey);
            storageContract.get(chunkKey, DecodeType.PaddingPer31Bytes, 0, length);

            assembly {
                returndatacopy(add(add(concatenatedData, offset), 0x20), 0x40, length)
            }
            offset += length;
        }

        return (concatenatedData, true);
    }

    function _removeChunkFromBlob(bytes32 key, uint256 chunkId) internal returns (bool) {
        bytes32 chunkKey = keyToChunks[key][chunkId];
        if (chunkKey == bytes32(0)) {
            return false;
        }
        if (keyToChunks[key][chunkId + 1] != bytes32(0)) {
            // only the last chunk can be removed
            return false;
        }

        storageContract.remove(keyToChunks[key][chunkId]);
        keyToChunks[key][chunkId] = bytes32(0);
        return true;
    }

    function _removeFromBlob(bytes32 key, uint256 chunkId) internal returns (uint256) {
        while (true) {
            bytes32 chunkKey = keyToChunks[key][chunkId];
            if (chunkKey == bytes32(0)) {
                break;
            }

            storageContract.remove(keyToChunks[key][chunkId]);
            keyToChunks[key][chunkId] = bytes32(0);
            chunkId++;
        }
        return chunkId;
    }

    function _preparePutFromBlob(bytes32 key, uint256 chunkId) private {
        bytes32 chunkKey = keyToChunks[key][chunkId];
        if (chunkKey == bytes32(0)) {
            require(chunkId == 0 || keyToChunks[key][chunkId - 1] != bytes32(0), "must replace or append");
        } else {
            storageContract.remove(keyToChunks[key][chunkId]);
        }
    }

    function _putChunks(
        bytes32 key,
        uint256[] memory chunkIds,
        uint256[] memory sizes
    ) internal {
        uint256 length = chunkIds.length;
        uint256 cost = storageContract.upfrontPayment();
        require(msg.value >= cost * length, "insufficient balance");

        for (uint8 i = 0; i < length; i++) {
            require(0 < sizes[i] && sizes[i] <= maxChunkSize, "invalid chunk length");
            _preparePutFromBlob(key, chunkIds[i]);

            bytes32 chunkKey = keccak256(abi.encode(msg.sender, key, chunkIds[i]));
            storageContract.putBlob{value : cost}(chunkKey, i, sizes[i]);
            keyToChunks[key][chunkIds[i]] = chunkKey;
        }
    }

    function _getChunkHashFromBlob(bytes32 key, uint256 chunkId) public view returns (bytes32) {
        if (chunkId >= _countChunksFromBlob(key)) {
            return bytes32(0);
        }
        return storageContract.hash(keyToChunks[key][chunkId]);
    }
}
