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

    uint32 public decodeBlobSize;
    EthStorageContract public storageContract;
    mapping(bytes32 => bytes32[]) internal keyToChunk;

    function initBlobParams(uint32 fileSize, address storageAddress) public onlyOwner {
        decodeBlobSize = fileSize;
        storageContract = EthStorageContract(storageAddress);
    }

    function setEthStorageContract(address storageAddress) public onlyOwner {
        storageContract = EthStorageContract(storageAddress);
    }

    function isSupportBlob() view public returns (bool) {
        return address(storageContract) != address(0) && upfrontPayment() >= 0;
    }

    function upfrontPayment() public view returns (uint256) {
        return storageContract.upfrontPayment();
    }

    function _countChunksFromBlob(bytes32 key) internal view returns (uint256) {
        return keyToChunk[key].length;
    }

    function _chunkSizeFromBlob(bytes32 key, uint256 chunkId) internal view returns (uint256, bool) {
        if (chunkId >= _countChunksFromBlob(key)) {
            return (0, false);
        }
        uint256 length = storageContract.size(keyToChunk[key][chunkId]);
        return (length, true);
    }

    function _sizeFromBlob(bytes32 key) internal view returns (uint256, uint256) {
        uint256 size_ = 0;
        uint256 chunkId_ = 0;
        while (true) {
            (uint256 chunkSize_, bool found) = _chunkSizeFromBlob(key, chunkId_);
            if (!found) {
                break;
            }
            size_ += chunkSize_;
            chunkId_++;
        }

        return (size_, chunkId_);
    }

    function _getChunkFromBlob(bytes32 key, uint256 chunkId) internal view returns (bytes memory, bool) {
        (uint256 length,) = _chunkSizeFromBlob(key, chunkId);
        if (length < 1) {
            return (new bytes(0), false);
        }

        bytes memory data = storageContract.get(keyToChunk[key][chunkId], DecodeType.PaddingPer31Bytes, 0, length);
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
            bytes32 chunkKey = keyToChunk[key][chunkId];
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
        require(_countChunksFromBlob(key) - 1 == chunkId, "only the last chunk can be removed");
        storageContract.remove(keyToChunk[key][chunkId]);
        keyToChunk[key].pop();
        return true;
    }

    function _removeFromBlob(bytes32 key, uint256 chunkId) internal returns (uint256) {
        require(_countChunksFromBlob(key) > 0, "the file has no content");

        for (uint256 i = _countChunksFromBlob(key) - 1; i >= chunkId;) {
            storageContract.remove(keyToChunk[key][chunkId]);
            keyToChunk[key].pop();
            if (i == 0) {
                break;
            } else {
                i--;
            }
        }
        return chunkId;
    }

    function _preparePutFromBlob(bytes32 key, uint256 chunkId) private {
        require(chunkId <= _countChunksFromBlob(key), "must replace or append");
        if (chunkId < _countChunksFromBlob(key)) {
            // replace, delete old blob
            storageContract.remove(keyToChunk[key][chunkId]);
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
            require(sizes[i] <= decodeBlobSize, "invalid chunk length");
            _preparePutFromBlob(key, chunkIds[i]);

            bytes32 chunkKey = keccak256(abi.encode(msg.sender, block.timestamp, chunkIds[i], i));
            storageContract.putBlob{value : cost}(chunkKey, i, sizes[i]);
            if (chunkIds[i] < _countChunksFromBlob(key)) {
                // replace
                keyToChunk[key][chunkIds[i]] = chunkKey;
            } else {
                // add
                keyToChunk[key].push(chunkKey);
            }
        }
    }

    function _getChunkHashFromBlob(bytes32 key, uint256 chunkId) public view returns (bytes32) {
        if (chunkId >= _countChunksFromBlob(key)) {
            return bytes32(0);
        }
        return storageContract.hash(keyToChunk[key][chunkId]);
    }
}

