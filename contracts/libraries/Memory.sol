// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

library Memory {
    // Size of a word, in bytes.
    uint256 internal constant WORD_SIZE = 32;
    // Size of the header of a 'bytes' array.
    uint256 internal constant BYTES_HEADER_SIZE = 32;
    // Address of the free memory pointer.
    uint256 internal constant FREE_MEM_PTR = 0x40;

    // Compares the 'len' bytes starting at address 'addr' in memory with the 'len'
    // bytes starting at 'addr2'.
    // Returns 'true' if the bytes are the same, otherwise 'false'.
    function equals(uint256 addr, uint256 addr2, uint256 len) internal pure returns (bool equal) {
        assembly {
            equal := eq(keccak256(addr, len), keccak256(addr2, len))
        }
    }

    // Compares the 'len' bytes starting at address 'addr' in memory with the bytes stored in
    // 'bts'. It is allowed to set 'len' to a lower value then 'bts.length', in which case only
    // the first 'len' bytes will be compared.
    // Requires that 'bts.length >= len'
    function equals(uint256 addr, uint256 len, bytes memory bts) internal pure returns (bool equal) {
        require(bts.length >= len);
        uint256 addr2;
        assembly {
            addr2 :=
                add(
                    bts,
                    /*BYTES_HEADER_SIZE*/
                    32
                )
        }
        return equals(addr, addr2, len);
    }

    // Allocates 'numBytes' bytes in memory. This will prevent the Solidity compiler
    // from using this area of memory. It will also initialize the area by setting
    // each byte to '0'.
    function allocate(uint256 numBytes) internal pure returns (uint256 addr) {
        // Take the current value of the free memory pointer, and update.
        assembly {
            addr :=
                mload(
                    /*FREE_MEM_PTR*/
                    0x40
                )
            mstore(
                /*FREE_MEM_PTR*/
                0x40,
                add(addr, numBytes)
            )
        }
        uint256 words = (numBytes + WORD_SIZE - 1) / WORD_SIZE;
        for (uint256 i = 0; i < words; i++) {
            assembly {
                mstore(
                    add(
                        addr,
                        mul(
                            i,
                            /*WORD_SIZE*/
                            32
                        )
                    ),
                    0
                )
            }
        }
    }

    // Copy 'len' bytes from memory address 'src', to address 'dest'.
    // This function does not check the or destination, it only copies
    // the bytes.
    function copy(uint256 src, uint256 dest, uint256 len) internal pure {
        // Copy word-length chunks while possible
        // Reverse copy to prevent out of memory bound error
        src = src + len;
        dest = dest + len;
        for (; len >= WORD_SIZE; len -= WORD_SIZE) {
            dest -= WORD_SIZE;
            src -= WORD_SIZE;

            assembly {
                mstore(dest, mload(src))
            }
        }

        if (len == 0) {
            return;
        }

        // Copy remaining bytes
        src = src - len;
        dest = dest - len;
        assembly {
            mstore(dest, mload(src))
        }
    }

    // Returns a memory pointer to the provided bytes array.
    function ptr(bytes memory bts) internal pure returns (uint256 addr) {
        assembly {
            addr := bts
        }
    }

    // Returns a memory pointer to the data portion of the provided bytes array.
    function dataPtr(bytes memory bts) internal pure returns (uint256 addr) {
        assembly {
            addr :=
                add(
                    bts,
                    /*BYTES_HEADER_SIZE*/
                    32
                )
        }
    }

    // This function does the same as 'dataPtr(bytes memory)', but will also return the
    // length of the provided bytes array.
    function fromBytes(bytes memory bts) internal pure returns (uint256 addr, uint256 len) {
        len = bts.length;
        assembly {
            addr :=
                add(
                    bts,
                    /*BYTES_HEADER_SIZE*/
                    32
                )
        }
    }

    // Creates a 'bytes memory' variable from the memory address 'addr', with the
    // length 'len'. The function will allocate new memory for the bytes array, and
    // the 'len bytes starting at 'addr' will be copied into that new memory.
    function toBytes(uint256 addr, uint256 len) internal pure returns (bytes memory bts) {
        bts = new bytes(len);
        uint256 btsptr;
        assembly {
            btsptr :=
                add(
                    bts,
                    /*BYTES_HEADER_SIZE*/
                    32
                )
        }
        copy(addr, btsptr, len);
    }

    // Get the word stored at memory address 'addr' as a 'uint'.
    function toUint(uint256 addr) internal pure returns (uint256 n) {
        assembly {
            n := mload(addr)
        }
    }

    // Get the word stored at memory address 'addr' as a 'bytes32'.
    function toBytes32(uint256 addr) internal pure returns (bytes32 bts) {
        assembly {
            bts := mload(addr)
        }
    }

    /*
    // Get the byte stored at memory address 'addr' as a 'byte'.
    function toByte(uint addr, uint8 index) internal pure returns (byte b) {
        require(index < WORD_SIZE);
        uint8 n;
        assembly {
            n := byte(index, mload(addr))
        }
        b = byte(n);
    }
    */
}
