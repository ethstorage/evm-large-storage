// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IERC5018.sol";
import "./LargeStorageManager.sol";
import "./BlobStorageManager.sol";
import "./ISemver.sol";

contract ERC5018 is LargeStorageManager, BlobStorageManager, IERC5018, ISemver {

    mapping(bytes32 => StorageMode) storageModes;

    constructor(
        uint8 slotLimit,
        uint32 maxChunkSize,
        address storageAddress
    ) LargeStorageManager(slotLimit) BlobStorageManager(maxChunkSize, storageAddress) {}

    /// @notice Semantic version.
    /// @custom:semver 1.0.0
    function version() public pure virtual returns (string memory) {
        return "1.0.0";
    }

    function getStorageMode(bytes memory name) public view returns (StorageMode) {
        return storageModes[keccak256(name)];
    }

    // Large storage methods
    function write(bytes memory name, bytes calldata data) public onlyOwner payable virtual override {
        // TODO: support multiple chunks
        return writeChunk(name, 0, data);
    }

    function read(bytes memory name) public view virtual override returns (bytes memory, bool) {
        bytes32 key = keccak256(name);
        StorageMode mode = storageModes[key];
        if (mode == StorageMode.Blob) {
            return _getFromBlob(key);
        } else if (mode == StorageMode.OnChain) {
            return _get(key);
        }
        return (new bytes(0), false);
    }

    function size(bytes memory name) public view virtual override returns (uint256, uint256) {
        bytes32 key = keccak256(name);
        StorageMode mode = storageModes[key];
        if (mode == StorageMode.Blob) {
            return _sizeFromBlob(key);
        } else if (mode == StorageMode.OnChain) {
            return _size(key);
        }
        return (0, 0);
    }

    function remove(bytes memory name) public virtual override onlyOwner returns (uint256) {
        bytes32 key = keccak256(name);
        StorageMode mode = storageModes[key];
        storageModes[key] = StorageMode.Uninitialized;
        if (mode == StorageMode.Blob) {
            return _removeFromBlob(key, 0);
        } else if (mode == StorageMode.OnChain) {
            return _remove(key, 0);
        }
        return 0;
    }

    function countChunks(bytes memory name) public view virtual override returns (uint256) {
        bytes32 key = keccak256(name);
        StorageMode mode = storageModes[key];
        if (mode == StorageMode.Blob) {
            return _countChunksFromBlob(key);
        } else if (mode == StorageMode.OnChain) {
            return _countChunks(key);
        }
        return 0;
    }

    // Chunk-based large storage methods
    function writeChunk(
        bytes memory name,
        uint256 chunkId,
        bytes calldata data
    ) public payable onlyOwner virtual override {
        bytes32 key = keccak256(name);
        StorageMode mode = storageModes[key];
        require(mode == StorageMode.Uninitialized || mode == StorageMode.OnChain, "Invalid storage mode");
        if (mode == StorageMode.Uninitialized) {
            storageModes[key] = StorageMode.OnChain;
        }
        _putChunkFromCalldata(key, chunkId, data, msg.value);
    }

    function writeChunks(
        bytes memory name,
        uint256[] memory chunkIds,
        uint256[] memory sizes
    ) public onlyOwner override payable {
        require(isSupportBlob(), "The current network does not support blob upload");

        bytes32 key = keccak256(name);
        StorageMode mode = storageModes[key];
        require(mode == StorageMode.Uninitialized || mode == StorageMode.Blob, "Invalid storage mode");
        if (mode == StorageMode.Uninitialized) {
            storageModes[key] = StorageMode.Blob;
        }
        _putChunks(key, chunkIds, sizes);
    }

    function readChunk(bytes memory name, uint256 chunkId) public view virtual override returns (bytes memory, bool) {
        bytes32 key = keccak256(name);
        StorageMode mode = storageModes[key];
        if (mode == StorageMode.Blob) {
            return _getChunkFromBlob(key, chunkId);
        } else if (mode == StorageMode.OnChain) {
            return _getChunk(key, chunkId);
        }
        return (new bytes(0), false);
    }

    function chunkSize(bytes memory name, uint256 chunkId) public view virtual override returns (uint256, bool) {
        bytes32 key = keccak256(name);
        StorageMode mode = storageModes[key];
        if (mode == StorageMode.Blob) {
            return _chunkSizeFromBlob(key, chunkId);
        } else if (mode == StorageMode.OnChain) {
            return _chunkSize(key, chunkId);
        }
        return (0, false);
    }

    function removeChunk(bytes memory name, uint256 chunkId) public virtual onlyOwner override returns (bool) {
        bytes32 key = keccak256(name);
        StorageMode mode = storageModes[key];
        if (mode == StorageMode.Blob) {
            return _removeChunkFromBlob(key, chunkId);
        } else if (mode == StorageMode.OnChain) {
            return _removeChunk(key, chunkId);
        }
        return false;
    }

    function truncate(bytes memory name, uint256 chunkId) public virtual onlyOwner override returns (uint256) {
        bytes32 key = keccak256(name);
        StorageMode mode = storageModes[key];
        if (mode == StorageMode.Blob) {
            return _removeFromBlob(key, chunkId);
        } else if (mode == StorageMode.OnChain) {
            return _remove(key, chunkId);
        }
        return 0;
    }

    function refund() public onlyOwner override {
        payable(owner()).transfer(address(this).balance);
    }

    function destruct() public onlyOwner override {
        selfdestruct(payable(owner()));
    }

    function getChunkHash(bytes memory name, uint256 chunkId) public override view returns (bytes32) {
        bytes32 key = keccak256(name);
        StorageMode mode = storageModes[key];
        if (mode == StorageMode.Blob) {
            return _getChunkHashFromBlob(key, chunkId);
        } else if (mode == StorageMode.OnChain) {
            (bytes memory localData,) = _getChunk(key, chunkId);
            return keccak256(localData);
        }
        return 0;
    }

    function getBatchChunkHashes(FileChunk[] memory fileChunks) external view returns (bytes32[] memory) {
        uint totalChunks = 0;

        for (uint i = 0; i < fileChunks.length; i++) {
            totalChunks += fileChunks[i].chunkIds.length;
        }

        bytes32[] memory hashes = new bytes32[](totalChunks);
        uint index = 0;
        for (uint i = 0; i < fileChunks.length; i++) {
            for (uint j = 0; j < fileChunks[i].chunkIds.length; j++) {
                hashes[index] = getChunkHash(fileChunks[i].name, fileChunks[i].chunkIds[j]);
                index++;
            }
        }
        return hashes;
    }

    function getUploadInfo(bytes memory name) public override view returns (StorageMode mode, uint256 count, uint256 payment) {
        bytes32 key = keccak256(name);
        mode = storageModes[key];

        if (mode == StorageMode.Blob) {
            count = _countChunksFromBlob(key);
        } else if (mode == StorageMode.OnChain) {
            count = _countChunks(key);
        } else {
            count = 0;
        }

        payment = address(storageContract) != address(0) ? upfrontPayment() : 0;
    }
}
