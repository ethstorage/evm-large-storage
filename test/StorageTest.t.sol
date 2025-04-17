// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "contracts/mock/StorageManagerTest.sol";

contract StorageManagerFuncTest is Test {
    StorageManagerTest sm;
    bytes32 key0 = 0x0000000000000000000000000000000000000000000000000000000000000000;
    bytes32 key1 = 0x0000000000000000000000000000000000000000000000000000000000000001;

    function setUp() public {
        sm = new StorageManagerTest(0);
    }

    function testPutGet() public {
        sm.put(key0, hex"112233");
        assertEq(sm.get(key0), hex"112233", "first write");

        sm.put(key0, hex"33221100");
        assertEq(sm.get(key0), hex"33221100", "overwrite same key");

        sm.put(key1, hex"33221100aabbccdd");
        assertEq(sm.get(key1), hex"33221100aabbccdd", "new key write");
        assertEq(sm.get(key0), hex"33221100", "key0 still correct");
    }

    function testPut2Get() public {
        sm.put2(key0, hex"112233");
        assertEq(sm.get(key0), hex"112233", "first put2");

        sm.put2(key0, hex"33221100");
        assertEq(sm.get(key0), hex"33221100", "overwrite with put2");

        sm.put2(key1, hex"33221100aabbccdd");
        assertEq(sm.get(key1), hex"33221100aabbccdd", "put2 new key");
        assertEq(sm.get(key0), hex"33221100", "key0 remains");
    }
}
