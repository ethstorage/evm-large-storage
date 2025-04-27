// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Memory.sol";
import "./StorageSlotFactory.sol";

library StorageHelper {
    function putRawFromCalldata(bytes calldata data) internal returns (address) {
        StorageSlotFactoryFromInput c = new StorageSlotFactoryFromInput(data);
        return address(c);
    }

    function sizeRaw(address addr) internal view returns (uint256, bool) {
        if (addr == address(0)) return (0, false);
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(addr)
        }
        return (codeSize, codeSize > 0);
    }

    function getRaw(address addr) internal view returns (bytes memory, bool) {
        (uint256 dataSize, bool found) = sizeRaw(addr);
        if (!found) return (new bytes(0), false);

        bytes memory data = new bytes(dataSize);
        assembly {
            // retrieve data size
            extcodecopy(addr, add(data, 0x20), 0, dataSize)
        }
        return (data, true);
    }

    function getRawAt(address addr, uint256 memoryPtr) internal view returns (uint256, bool) {
        (uint256 dataSize, bool found) = sizeRaw(addr);
        if (!found) return (0, false);

        assembly {
            extcodecopy(addr, memoryPtr, 0, dataSize)
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
