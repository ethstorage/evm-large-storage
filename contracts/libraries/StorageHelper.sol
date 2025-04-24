// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Memory.sol";
import "./StorageSlotFactory.sol";

library StorageHelper {
    // StorageSlotSelfDestructable compiled via solc 0.8.7 optimized 200
    bytes internal constant STORAGE_SLOT_CODE =
        hex"6080604052348015600f57600080fd5b506004361060325760003560e01c80632b68b9c61460375780638da5cb5b14603f575b600080fd5b603d6081565b005b60657f000000000000000000000000000000000000000000000000000000000000000081565b6040516001600160a01b03909116815260200160405180910390f35b336001600160a01b037f0000000000000000000000000000000000000000000000000000000000000000161460ed5760405162461bcd60e51b815260206004820152600e60248201526d3737ba10333937b69037bbb732b960911b604482015260640160405180910390fd5b33fffea2646970667358221220fc66c9afb7cb2f6209ae28167cf26c6c06f86a82cbe3c56de99027979389a1be64736f6c63430008070033";
    uint256 internal constant ADDR_OFF0 = 67;
    uint256 internal constant ADDR_OFF1 = 140;

    function putRawFromCalldata(bytes calldata data, uint256 value) internal returns (address) {
        bytes memory bytecode = bytes.concat(STORAGE_SLOT_CODE, data);
        {
            // revise the owner to the contract (so that it is destructable)
            uint256 off = ADDR_OFF0 + 0x20;
            assembly {
                mstore(add(bytecode, off), address())
            }
            off = ADDR_OFF1 + 0x20;
            assembly {
                mstore(add(bytecode, off), address())
            }
        }

        StorageSlotFactoryFromInput c = new StorageSlotFactoryFromInput{value: value}(bytecode);
        return address(c);
    }

    function putRaw(bytes memory data, uint256 value) internal returns (address) {
        // create the new contract code with the data
        bytes memory bytecode = STORAGE_SLOT_CODE;
        uint256 bytecodeLen = bytecode.length;
        uint256 newSize = bytecode.length + data.length;
        assembly {
            // in-place resize of bytecode bytes
            // note that this must be done when bytecode is the last allocated object by solidity.
            mstore(bytecode, newSize)
            // notify solidity about the memory size increase, must be 32-bytes aligned
            mstore(0x40, add(bytecode, and(add(add(newSize, 0x20), 0x1f), not(0x1f))))
        }
        // append data to self-destruct byte code
        Memory.copy(Memory.dataPtr(data), Memory.dataPtr(bytecode) + bytecodeLen, data.length);
        {
            // revise the owner to the contract (so that it is destructable)
            uint256 off = ADDR_OFF0 + 0x20;
            assembly {
                mstore(add(bytecode, off), address())
            }
            off = ADDR_OFF1 + 0x20;
            assembly {
                mstore(add(bytecode, off), address())
            }
        }

        StorageSlotFactoryFromInput c = new StorageSlotFactoryFromInput{value: value}(bytecode);
        return address(c);
    }

    function sizeRaw(address addr) internal view returns (uint256, bool) {
        if (addr == address(0x0)) {
            return (0, false);
        }
        uint256 codeSize;
        uint256 off = STORAGE_SLOT_CODE.length;
        assembly {
            codeSize := extcodesize(addr)
        }
        if (codeSize < off) {
            return (0, false);
        }

        return (codeSize - off, true);
    }

    function getRaw(address addr) internal view returns (bytes memory, bool) {
        (uint256 dataSize, bool found) = sizeRaw(addr);

        if (!found) {
            return (new bytes(0), false);
        }

        // copy the data without the "code"
        bytes memory data = new bytes(dataSize);
        uint256 off = STORAGE_SLOT_CODE.length;
        assembly {
            // retrieve data size
            extcodecopy(addr, add(data, 0x20), off, dataSize)
        }
        return (data, true);
    }

    function getRawAt(address addr, uint256 memoryPtr) internal view returns (uint256, bool) {
        (uint256 dataSize, bool found) = sizeRaw(addr);

        if (!found) {
            return (0, false);
        }

        uint256 off = STORAGE_SLOT_CODE.length;
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
