// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Memory.sol";
import "./StorageSlotFactory.sol";

library StorageHelper {
    // Minimal runtime that returns everything after the first 11 bytes (0x0b) of code
    // Opcode explanation: PUSH1 0x0b CODECOPY RETURNDATASIZE RETURN
    // Full sequence: 0x60 0x0b 0x59 0x81 0x38 0x03 0x80 0x92 0x59 0x39 0xf3
    bytes internal constant MINIMAL_RUNTIME = hex"600b5981380380925939f3";

    function putRawFromCalldata(bytes calldata data) internal returns (address) {
        // Append the runtime code with data (data will be part of the deployed code)
        bytes memory runtimeCode = bytes.concat(MINIMAL_RUNTIME, data);

        // Encode the creation code of StorageSlotFactoryFromInput with the runtimeCode as constructor input
        bytes memory deployCode =
            abi.encodePacked(type(StorageSlotFactoryFromInput).creationCode, abi.encode(runtimeCode));

        // Deploy the contract using CREATE and return the deployed address
        address deployed;
        assembly {
            deployed := create(0, add(deployCode, 0x20), mload(deployCode))
        }
        require(deployed != address(0), "deploy failed");
        return deployed;
    }

    function sizeRaw(address addr) internal view returns (uint256, bool) {
        if (addr == address(0)) return (0, false);
        uint256 codeSize;
        uint256 off = MINIMAL_RUNTIME.length;
        assembly {
            codeSize := extcodesize(addr)
        }
        if (codeSize < off) return (0, false);
        return (codeSize - off, true);
    }

    function getRaw(address addr) internal view returns (bytes memory, bool) {
        (uint256 dataSize, bool found) = sizeRaw(addr);
        if (!found) return (new bytes(0), false);

        // copy the data without the "code"
        bytes memory data = new bytes(dataSize);
        uint256 off = MINIMAL_RUNTIME.length;
        assembly {
            // retrieve data size
            extcodecopy(addr, add(data, 0x20), off, dataSize)
        }
        return (data, true);
    }

    function getRawAt(address addr, uint256 memoryPtr) internal view returns (uint256, bool) {
        (uint256 dataSize, bool found) = sizeRaw(addr);
        if (!found) return (0, false);

        uint256 off = MINIMAL_RUNTIME.length;
        assembly {
            // retrieve data size
            extcodecopy(addr, memoryPtr, off, dataSize)
        }
        return (dataSize, true);
    }

    function returnBytesInplace(bytes memory content) internal pure {
        // equal to return abi.encode(content)
        uint256 size = content.length + 0x40; // pointer + size
        size = (size + 0x1f) & ~uint256(0x1f);
        assembly {
            // (DATA CORRUPTION): the caller method must be "external returns (bytes)", cannot be public!
            mstore(sub(content, 0x20), 0x20)
            return(sub(content, 0x20), size)
        }
    }
}
