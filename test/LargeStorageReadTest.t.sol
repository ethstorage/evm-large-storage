// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "contracts/mocks/FlatDirectoryTest.sol";

contract FlatDirectoryLargeReadTest is Test {
    FlatDirectoryTest fd;

    function setUp() public {
        fd = new FlatDirectoryTest(0, 0, address(0));
    }

    function _randomBytes(uint256 length, uint256 seed) internal pure returns (bytes memory) {
        bytes memory result = new bytes(length);
        for (uint256 i = 0; i < length; i++) {
            result[i] = bytes1(uint8(uint256(keccak256(abi.encode(seed, i))) % 256));
        }
        return result;
    }

    function testLargeWriteAndRead() public {
        bytes memory key = bytes("abc");
        uint256 nchunk = 10;

        bytes memory fullData;

        for (uint256 i = 0; i < nchunk; i++) {
            bytes memory chunk = _randomBytes(12 * 1024, i);
            fd.writeChunk(key, i, chunk);
            fullData = bytes.concat(fullData, chunk);
        }

        fd.readNonView(key);
        fd.readManual(key);

        // for comparison
        // 85 chunks
        // - readNonView: 12844889
        // - readManual: 3278113
    }
}
