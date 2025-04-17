// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "contracts/mock/StorageManagerTest.sol";

contract OptimizedStorageManagerTest is Test {
    StorageManagerTest osm;
    bytes32 key;

    function setUp() public {
        osm = new StorageManagerTest(220);
        key = hex"00000000000000000000000000000000000000000000000000000000000000aa";
    }

    function oneStoreTest(uint256 filesize, uint8 expectedWhere) internal {
        bytes memory data = new bytes(filesize);
        for (uint256 i = 0; i < filesize; i++) {
            data[i] = 0x01;
        }

        osm.put(key, data);

        bytes memory resData = osm.get(key);
        uint256 fsize = osm.filesize(key);
        uint256 _where = osm.whereStore(key);

        assertEq(resData, data, "data mismatch");
        assertEq(fsize, filesize, "filesize mismatch");
        assertEq(_where, expectedWhere, "whereStore mismatch");
    }

    function removeTest() internal {
        osm.remove(key);
        uint256 fsize = osm.filesize(key);
        assertEq(fsize, 0, "remove failed");
    }

    function testWriteMin220Bytes() public {
        oneStoreTest(100, 1);
    }

    function testWriteEqual220Bytes() public {
        oneStoreTest(220, 1);
    }

    function testWriteOver220Bytes() public {
        oneStoreTest(250, 2);
    }

    function testRewriteFileSequence() public {
        oneStoreTest(220, 1);
        oneStoreTest(300, 2);
        oneStoreTest(100, 1);
    }

    function testWriteAndRemove100Bytes() public {
        oneStoreTest(100, 1);
        removeTest();
    }

    function testWriteAndRemove300Bytes() public {
        oneStoreTest(300, 2);
        removeTest();
    }

    function testWriteAndRemoveMultipleTimes() public {
        oneStoreTest(100, 1);
        removeTest();
        oneStoreTest(300, 2);
        removeTest();
        oneStoreTest(1, 1);
        removeTest();
    }
}
