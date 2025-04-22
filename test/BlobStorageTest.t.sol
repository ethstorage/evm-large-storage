// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "contracts/core/ERC5018.sol";
import "contracts/mocks/EthStorageContractTest.sol";

using stdStorage for StdStorage;

contract ERC5018Test is Test {
    EthStorageContractTest storageContract;
    ERC5018 ercBlob;

    bytes fileName = bytes("test.txt");
    bytes hexName;

    uint32 constant BLOB_SIZE = (4 * 31 + 3) * 1024 - 4;

    function setUp() public {
        storageContract = new EthStorageContractTest();
        ercBlob = new ERC5018(0, BLOB_SIZE, address(storageContract));
        hexName = bytes("test.txt");
    }

    function createBytes(uint256 length, uint8 val) internal pure returns (bytes memory) {
        bytes memory buf = new bytes(length);
        for (uint256 i = 0; i < length; i++) {
            buf[i] = bytes1(val);
        }
        return buf;
    }

    function testPutAndGet() public {
        uint256 fileSize = BLOB_SIZE * 2 + 1024;
        bytes memory fileData = createBytes(fileSize, 0x01);

        uploadFile(fileData);

        (uint256 actualSize, ) = ercBlob.size(hexName);
        assertEq(actualSize, fileSize);

        uint256 chunkCount = ercBlob.countChunks(hexName);
        assertEq(chunkCount, 3);

        // chunk size
        (uint256 chunkSize0, ) = ercBlob.chunkSize(hexName, 0);
        assertEq(chunkSize0, BLOB_SIZE);

        (uint256 chunkSize2, ) = ercBlob.chunkSize(hexName, 2);
        assertEq(chunkSize2, fileSize - BLOB_SIZE * 2);

        // chunk hash
        bytes32 chunkHash0 = ercBlob.getChunkHash(hexName, 0);
        bytes32 localHash0 = createLocalHash(BLOB_SIZE);
        assertEq(chunkHash0, localHash0);

        bytes32 chunkHash2 = ercBlob.getChunkHash(hexName, 2);
        bytes32 localHash2 = createLocalHash(fileSize - BLOB_SIZE * 2);
        assertEq(chunkHash2, localHash2);

        // file hash
        (bytes memory outData, ) = ercBlob.read(hexName);
        assertEq(keccak256(outData), keccak256(fileData));
    }

    function testRemove() public {
        uint256 fileSize = BLOB_SIZE * 4;
        bytes memory fileData = createBytes(fileSize, 0x01);

        uploadFile(fileData);

        // Remove last chunk
        ercBlob.removeChunk(hexName, 3);
        (uint256 sizeAfterRemove, ) = ercBlob.size(hexName);
        assertEq(sizeAfterRemove, BLOB_SIZE * 3);

        // Truncate to 1
        ercBlob.truncate(hexName, 1);
        (uint256 sizeAfterTruncate, ) = ercBlob.size(hexName);
        assertEq(sizeAfterTruncate, BLOB_SIZE);

        // Remove all
        ercBlob.remove(hexName);
        (uint256 finalSize, ) = ercBlob.size(hexName);
        assertEq(finalSize, 0);
    }

    // === Utility ===
    function uploadFile(bytes memory fileData) internal {
        uint256 numChunks = (fileData.length + BLOB_SIZE - 1) / BLOB_SIZE;

        uint256[] memory chunkIds = new uint256[](numChunks);
        uint256[] memory chunkSizes = new uint256[](numChunks);
        bytes[] memory chunkDatas = new bytes[](numChunks);
        for (uint256 i = 0; i < numChunks; i++) {
            chunkIds[i] = i;
            uint256 start = i * BLOB_SIZE;
            uint256 end = (start + BLOB_SIZE > fileData.length) ? fileData.length : (start + BLOB_SIZE);
            chunkSizes[i] = end - start;
            chunkDatas[i] = slice(fileData, start, end);
        }

        vm.deal(address(this), 1 ether);
        uint256 cost = ercBlob.upfrontPayment() * numChunks;
        vm.recordLogs();

        ercBlob.writeChunks{value: cost}(hexName, chunkIds, chunkSizes);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 j = 0; j < logs.length; j++) {
            Vm.Log memory log = logs[j];
            if (log.topics[0] == keccak256("PutBlob(bytes32,uint256,uint256)")) {
                bytes memory data = log.data;
                bytes32 key;
                assembly {
                    key := mload(add(data, 0x20))
                }
                uploadCallData(key, chunkDatas[j]);
            }
        }
    }

    function uploadCallData(bytes32 key, bytes memory buffer) internal {
        uint256 maxChunkSize = 24 * 1024 - 326; // 24KB
        uint256 totalSize = buffer.length;
        uint256 offset = 0;
        uint256 index = 0;

        while (offset < totalSize) {
            uint256 remaining = totalSize - offset;
            uint256 chunkSize = remaining > maxChunkSize ? maxChunkSize : remaining;

            // Copy `chunkSize` bytes from `buffer` starting at `offset`
            bytes memory chunk = new bytes(chunkSize);
            for (uint256 i = 0; i < chunkSize; i++) {
                chunk[i] = buffer[offset + i];
            }
            storageContract.writeBlobChunk(key, index, chunk);
            offset += chunkSize;
            index++;
        }
    }

    function createLocalHash(uint256 length) public pure returns (bytes32) {
        bytes memory buf = new bytes(length);
        for (uint256 i = 0; i < length; i++) {
            buf[i] = 0x01;
        }

        bytes32 fullHash = keccak256(buf);
        bytes memory result = new bytes(32);
        for (uint256 i = 0; i < 24; i++) {
            result[i] = fullHash[i];
        }
        return bytes32(bytes(result));
    }


    function slice(bytes memory data, uint256 start, uint256 end) internal pure returns (bytes memory) {
        bytes memory result = new bytes(end - start);
        for (uint256 i = 0; i < end - start; i++) {
            result[i] = data[start + i];
        }
        return result;
    }
}
