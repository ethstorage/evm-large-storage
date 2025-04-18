// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "contracts/FlatDirectory.sol";

contract OptimizedFlatDirectoryTest is Test {
    FlatDirectory fd;

    function setUp() public {
        fd = new FlatDirectory(220, 0, address(0));
    }

    function _generateBytes(uint256 len, uint8 context) internal pure returns (bytes memory out) {
        out = new bytes(len);
        for (uint256 i = 0; i < len; ++i) {
            out[i] = bytes1(context);
        }
    }

    function _write(bytes memory key, uint256 size, uint8 context) internal {
        bytes memory data = _generateBytes(size, context);
        fd.write(key, data);
        (bytes memory out, bool ok) = fd.read(key);
        (uint256 sz,) = fd.size(key);
        assertTrue(ok);
        assertEq(out, data);
        assertEq(sz, size);
    }

    function _writeChunk(bytes memory key, uint256 chunkId, uint256 size, uint8 context) internal {
        bytes memory data = _generateBytes(size, context);
        fd.writeChunk(key, chunkId, data);
        (bytes memory out, bool ok) = fd.readChunk(key, chunkId);
        (uint256 sz,) = fd.chunkSize(key, chunkId);
        assertTrue(ok);
        assertEq(out, data);
        assertEq(sz, size);
    }

    function _readAll(bytes memory key, uint256 size, bytes memory expected) internal {
        (bytes memory out, bool ok) = fd.read(key);
        (uint256 sz,) = fd.size(key);
        assertTrue(ok);
        assertEq(out, expected);
        assertEq(sz, size);
    }

    function testWriteAndRead() public {
        _write("0x01", 100, 1);
        _write("0x02", 1000, 1);
        _write("0x03", 10000, 1);
    }

    function testRewrite() public {
        _write("0x01", 100, 1);
        _write("0x01", 1000, 2);
        _write("0x01", 10000, 3);
    }

    function testWriteChunk() public {
        _writeChunk("0x01", 0, 100, 1);
        _writeChunk("0x01", 1, 1000, 2);
        _writeChunk("0x01", 2, 10000, 3);
    }

    function testWriteVariableSizedChunk() public {
        for (uint256 size = 1; size < 300; ++size) {
            _writeChunk("0x01", 0, size, 1);
            fd.removeChunk("0x01", 0);
        }
    }

    function testRewriteThroughChunk() public {
        _writeChunk("0x01", 0, 1000, 1);
        _writeChunk("0x01", 1, 1000, 2);
        _writeChunk("0x01", 0, 10000, 4);
        _writeChunk("0x01", 0, 10, 3);
        _writeChunk("0x01", 1, 10, 5);
    }

    function testReadAllChunk() public {
        _writeChunk("0x01", 0, 100, 1);
        _writeChunk("0x01", 1, 1000, 2);
        _writeChunk("0x01", 2, 10000, 3);

        bytes memory total1 = bytes.concat(
            _generateBytes(100, 1),
            _generateBytes(1000, 2),
            _generateBytes(10000, 3)
        );
        _readAll("0x01", 100 + 1000 + 10000, total1);

        _writeChunk("0x02", 0, 1000, 1);
        _writeChunk("0x02", 1, 10, 2);
        _writeChunk("0x02", 2, 100, 3);

        bytes memory total2 = bytes.concat(
            _generateBytes(1000, 1),
            _generateBytes(10, 2),
            _generateBytes(100, 3)
        );
        _readAll("0x02", 1000 + 10 + 100, total2);
    }

    function testWriteChunkRevertsOnNoAppend() public {
        bytes memory key = hex"01";
        bytes memory data0 = _generateBytes(1000, 1);
        fd.writeChunk(key, 0, data0);

        bytes memory data2 = _generateBytes(500, 4);
        vm.expectRevert();
        fd.writeChunk(key, 2, data2);
    }

    function testRemoveAndReWrite() public {
        _writeChunk("0x01", 0, 1000, 1);
        _writeChunk("0x01", 1, 100, 2);
        _writeChunk("0x01", 2, 100, 3);
        fd.remove("0x01");

        (bytes memory out, bool ok) = fd.read("0x01");
        assertEq(out.length, 0);
        assertTrue(ok == false);

        _writeChunk("0x01", 0, 1000, 1);
        _writeChunk("0x01", 1, 100, 2);
        _writeChunk("0x01", 2, 100, 3);
    }

    function testChunkManipulation() public {
        bytes memory key = "abc";
        assertEq(fd.countChunks(key), 0);

        bytes memory d0 = _generateBytes(10, 1);
        fd.write(key, d0);

        (bytes memory r0, ) = fd.read(key);
        assertEq(r0, d0);

        bytes memory d1 = _generateBytes(20, 2);
        fd.writeChunk(key, 1, d1);
        (bytes memory r1,) = fd.readChunk(key, 1);
        assertEq(r1, d1);

        fd.removeChunk(key, 0);
        (uint256 size, uint256 chunks) = fd.size(key);
        assertEq(size, 30);
        assertEq(chunks, 2);

        (bytes memory r0_2,) = fd.readChunk(key, 0);
        assertEq(r0_2, d0);

        fd.removeChunk(key, 1);
        (uint256 newSize, uint256 newChunks) = fd.size(key);
        assertEq(newSize, 10);
        assertEq(newChunks, 1);
        (bytes memory r1_2, bool ok2) = fd.readChunk(key, 1);
        assertEq(r1_2.length, 0);
        assertTrue(ok2 == false);
        assertEq(fd.countChunks(key), 1);
    }
}
