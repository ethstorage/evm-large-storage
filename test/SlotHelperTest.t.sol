// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "contracts/mocks/SlotHelperTest.sol";

contract SlotHelperTestSuite is Test {
    SlotHelperTest slotHelper;

    uint256 constant SHIFTLEFT224BIT = 16 ** 56;

    function setUp() public {
        slotHelper = new SlotHelperTest();
    }

    function testEncodeDecodeLen() public {
        uint256 len = 20;
        bytes32 encoded = slotHelper.encodeLen(len);
        uint256 encodedInt = uint256(encoded);
        uint256 expected = len * SHIFTLEFT224BIT;

        assertEq(encodedInt, expected, "Encoded length mismatch");

        uint256 decoded = slotHelper.decodeLen(encoded);
        assertEq(decoded, len, "Decoded length mismatch");
    }

    function testEncodeDecodeMetadata() public {
        uint256 len = 20;
        bytes memory data = hex"0101010101010101010101010101010101010101"; // 20 bytes of 0x01

        bytes32 metadata = slotHelper.encodeMetadata(data);

        (uint256 resLen1, ) = slotHelper.decodeMetadata(metadata);
        assertEq(resLen1, len, "decodeMetadata: length mismatch");

        (uint256 resLen2, bytes memory resData2) = slotHelper.decodeMetadata1(metadata);
        assertEq(resLen2, len, "decodeMetadata1: length mismatch");
        assertEq(resData2, data, "decodeMetadata1: data mismatch");

        uint256 resLen3 = slotHelper.decodeLen(metadata);
        assertEq(resLen3, len, "decodeLen(metadata) mismatch");
    }

    function testPutAndGet() public {
        bytes32 key = hex"00000000000000000000000000000000000000000000000000000000000000aa";
        bytes memory data = hex"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"; // 17 bytes
        uint256 datalen = 17;

        slotHelper.put(key, data);

        bytes memory returned = slotHelper.get(key);
        uint256 len = slotHelper.getLen(key);

        assertEq(returned, data, "Returned data mismatch");
        assertEq(len, datalen, "Data length mismatch");
    }

    function testPutAndGetOver28Bytes() public {
        bytes32 key = hex"00000000000000000000000000000000000000000000000000000000000000aa";
        bytes memory data = hex"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"; // 64 bytes
        uint256 datalen = 64;

        slotHelper.put(key, data);

        bytes memory returned = slotHelper.get(key);
        uint256 len = slotHelper.getLen(key);

        assertEq(returned, data, "Returned long data mismatch");
        assertEq(len, datalen, "Long data length mismatch");
    }
}
