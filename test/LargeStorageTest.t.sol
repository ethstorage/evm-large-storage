// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "contracts/FlatDirectory.sol";

contract FlatDirectoryTest is Test {
    FlatDirectory fd;

    function setUp() public {
        fd = new FlatDirectory(0, 0, address(0));
    }

    function testReadWrite() public {
        bytes memory name = hex"616263";
        bytes memory data = hex"112233";
        fd.write(name, data);

        (bytes memory result, bool ok) = fd.read(name);
        assertTrue(ok);
        assertEq(result, data);

        bytes memory randomData = _randBytes(40);
        fd.write(name, randomData);

        (result, ok) = fd.read(name);
        assertTrue(ok);
        assertEq(result, randomData);

        (uint256 size, uint256 count) = fd.size(name);
        assertEq(size, 40);
        assertEq(count, 1);
    }

    function testReadWriteChunks() public {
        bytes memory name = hex"616263";
        bytes memory chunk0 = _randBytes(1024);
        fd.write(name, chunk0);

        (bytes memory result, bool ok) = fd.read(name);
        assertTrue(ok);
        assertEq(result, chunk0);

        bytes memory chunk1 = _randBytes(512);
        fd.writeChunk(name, 1, chunk1);

        (result, ok) = fd.readChunk(name, 1);
        assertTrue(ok);
        assertEq(result, chunk1);

        bytes memory concat = bytes.concat(chunk0, chunk1);
        (result, ok) = fd.read(name);
        assertTrue(ok);
        assertEq(result, concat);

        (uint256 size, uint256 count) = fd.size(name);
        assertEq(size, 1536);
        assertEq(count, 2);
    }

    function testWriteRemoveChunks() public {
        bytes memory name = hex"616263";
        assertEq(fd.countChunks(name), 0);

        bytes memory chunk0 = _randBytes(10);
        fd.write(name, chunk0);

        (bytes memory result, bool ok) = fd.read(name);
        assertTrue(ok);
        assertEq(result, chunk0);

        bytes memory chunk1 = _randBytes(20);
        fd.writeChunk(name, 1, chunk1);

        (result, ok) = fd.readChunk(name, 1);
        assertTrue(ok);
        assertEq(result, chunk1);

        bool removed = fd.removeChunk(name, 0);
        assertTrue(!removed, "Only the last chunk can be removed");
        (uint256 size, uint256 count) = fd.size(name);
        assertEq(size, 30);
        assertEq(count, 2);

        (result, ok) = fd.readChunk(name, 0);
        assertTrue(ok);
        assertEq(result, chunk0);

        removed = fd.removeChunk(name, 1);
        assertTrue(removed, "Failed to remove chunk 1");
        (size, count) = fd.size(name);
        assertEq(size, 10);
        assertEq(count, 1);

        (result, ok) = fd.readChunk(name, 1);
        assertFalse(ok);
        assertEq(result, "");
        assertEq(fd.countChunks(name), 1);
    }

    function testTruncateChunks() public {
        bytes memory name = hex"616263";
        assertEq(fd.countChunks(name), 0);

        bytes memory chunk0 = _randBytes(10);
        fd.write(name, chunk0);

        bytes memory chunk1 = _randBytes(20);
        fd.writeChunk(name, 1, chunk1);

        bytes memory chunk2 = _randBytes(30);
        fd.writeChunk(name, 2, chunk2);

        fd.truncate(name, 3); // no-op
        (uint256 size, uint256 count) = fd.size(name);
        assertEq(size, 60);
        assertEq(count, 3);

        (bytes memory result, bool ok) = fd.read(name);
        assertTrue(ok);
        assertEq(result, bytes.concat(chunk0, chunk1, chunk2));

        fd.truncate(name, 1); // truncate to 1 chunk
        (size, count) = fd.size(name);
        assertEq(size, 10);
        assertEq(count, 1);

        (result, ok) = fd.read(name);
        assertTrue(ok);
        assertEq(result, chunk0);

        (result, ok) = fd.readChunk(name, 1);
        assertFalse(ok);
        assertEq(result, "");
    }

    function testFallbackReadFile() public {
        bytes memory name = hex"616263";
        bytes memory chunk0 = _randBytes(10);
        fd.write(name, chunk0);

        (bool success, bytes memory returndata) = address(fd).call(hex"2f616263");
        assertTrue(success);

        bytes memory decoded = abi.decode(returndata, (bytes));
        assertEq(decoded, chunk0);
    }

    function testFallbackReadIndexHtml() public {
        bytes memory indexFile = bytes("index.html");
        fd.setDefault(indexFile);

        bytes memory content = _randBytes(10);
        fd.write(indexFile, content);

        (bool success, bytes memory returndata) = address(fd).call(hex"2f");
        assertTrue(success);

        bytes memory decoded = abi.decode(returndata, (bytes));
        assertEq(decoded, content);

        bytes memory secondaryIndex = bytes("dir1/index.html");
        bytes memory content2 = _randBytes(10);
        fd.write(secondaryIndex, content2);

        (success, returndata) = address(fd).call(bytes("/dir1/"));
        assertTrue(success);
        decoded = abi.decode(returndata, (bytes));
        assertEq(decoded, content2);

        (success, returndata) = address(fd).call(bytes("/dir1"));
        assertTrue(success);
        decoded = abi.decode(returndata, (bytes));
        assertEq(decoded, ""); // fallback returns empty for "/dir1"
    }

    function _randBytes(uint256 len) internal view returns (bytes memory out) {
        out = new bytes(len);
        for (uint256 i = 0; i < len; ++i) {
            out[i] = bytes1(uint8(uint256(keccak256(abi.encodePacked(block.timestamp, i))) % 256));
        }
    }
}
