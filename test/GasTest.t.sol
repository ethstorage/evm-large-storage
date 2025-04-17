// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "contracts/mock/StorageManagerTest.sol";
import "contracts/mock/StorageManagerLocalTest.sol";

contract StorageManagerGasTest is Test {
    StorageManagerTest sm;
    StorageManagerLocalTest sml;

    bytes32 constant KEY = 0x0000000000000000000000000000000000000000000000000000000000000000;

    function _generateBytes(uint256 size) internal pure returns (bytes memory out) {
        out = new bytes(size);
        for (uint256 i = 0; i < size; ++i) {
            out[i] = 0x01;
        }
    }

    function testPutGet_1k() public {
        sm = new StorageManagerTest(0);
        bytes memory value = _generateBytes(1024);
        sm.put(KEY, value);
        sm.getWithoutView(KEY);
    }

    function testPutGet_4k() public {
        sm = new StorageManagerTest(0);
        bytes memory value = _generateBytes(4096);
        sm.put(KEY, value);
        sm.getWithoutView(KEY);
    }

    function testPutGet_8k() public {
        sm = new StorageManagerTest(0);
        bytes memory value = _generateBytes(8192);
        sm.put(KEY, value);
        sm.getWithoutView(KEY);
    }

    function testPutGet_12k() public {
        sm = new StorageManagerTest(0);
        bytes memory value = _generateBytes(12288);
        sm.put(KEY, value);
        sm.getWithoutView(KEY);
    }

    function testPut2Get_12k() public {
        sm = new StorageManagerTest(0);
        bytes memory value = _generateBytes(12288);
        sm.put2(KEY, value);
        sm.getWithoutView(KEY);
    }

    function testPutGet_Inplace_12k() public {
        sm = new StorageManagerTest(0);
        bytes memory value = _generateBytes(12288);
        sm.put(KEY, value);
        sm.put(KEY, value);
        sm.getWithoutView(KEY);
    }

    function testLocalPutGet_1k() public {
        sml = new StorageManagerLocalTest();
        bytes memory value = _generateBytes(1024);
        sml.put(KEY, value);
        sml.getWithoutView(KEY);
    }

    function testLocalPutGet_4k() public {
        sml = new StorageManagerLocalTest();
        bytes memory value = _generateBytes(4096);
        sml.put(KEY, value);
        sml.getWithoutView(KEY);
    }

    function testLocalPutGet_8k() public {
        sml = new StorageManagerLocalTest();
        bytes memory value = _generateBytes(8192);
        sml.put(KEY, value);
        sml.getWithoutView(KEY);
    }

    function testLocalPutGet_12k() public {
        sml = new StorageManagerLocalTest();
        bytes memory value = _generateBytes(12288);
        sml.put(KEY, value);
        sml.getWithoutView(KEY);
    }

    function testLocalPutGet_Inplace_12k() public {
        sml = new StorageManagerLocalTest();
        bytes memory value = _generateBytes(12288);
        sml.put(KEY, value);
        sml.put(KEY, value);
        sml.getWithoutView(KEY);
    }
}
