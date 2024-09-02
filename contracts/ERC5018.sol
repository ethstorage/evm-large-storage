// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IERC5018.sol";
import "./LargeStorageManager.sol";
import "./BlobStorageManager.sol";
import "./ISemver.sol";

contract ERC5018 is LargeStorageManager, BlobStorageManager, IERC5018, ISemver {

    enum StorageMode {
        Uninitialized,
        OnChain,
        Blob
    }
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

    function _setStorageMode(bytes memory name, StorageMode mode) internal {
        storageModes[keccak256(name)] = mode;
    }

    // Large storage methods
    function write(bytes memory name, bytes calldata data) public onlyOwner payable virtual override {
        // TODO: support multiple chunks
        return writeChunk(name, 0, data);
    }

    function read(bytes memory name) public view virtual override returns (bytes memory, bool) {
        StorageMode mode = getStorageMode(name);
        if (mode == StorageMode.Blob) {
            return _getFromBlob(keccak256(name));
        } else if (mode == StorageMode.OnChain) {
            return _get(keccak256(name));
        }
        return (new bytes(0), false);
    }

    function size(bytes memory name) public view virtual override returns (uint256, uint256) {
        StorageMode mode = getStorageMode(name);
        if (mode == StorageMode.Blob) {
            return _sizeFromBlob(keccak256(name));
        } else if (mode == StorageMode.OnChain) {
            return _size(keccak256(name));
        }
        return (0, 0);
    }

    function remove(bytes memory name) public virtual override onlyOwner returns (uint256) {
        StorageMode mode = getStorageMode(name);
        if (mode == StorageMode.Blob) {
            return _removeFromBlob(keccak256(name), 0);
        } else if (mode == StorageMode.OnChain) {
            return _remove(keccak256(name), 0);
        }
        return 0;
    }

    function countChunks(bytes memory name) public view virtual override returns (uint256) {
        StorageMode mode = getStorageMode(name);
        if (mode == StorageMode.Blob) {
            return _countChunksFromBlob(keccak256(name));
        } else if (mode == StorageMode.OnChain) {
            return _countChunks(keccak256(name));
        }
        return 0;
    }

    // Chunk-based large storage methods
    function writeChunk(
        bytes memory name,
        uint256 chunkId,
        bytes calldata data
    ) public payable onlyOwner virtual override {
        StorageMode mode = getStorageMode(name);
        require(mode == StorageMode.Uninitialized || mode == StorageMode.OnChain, "Invalid storage mode");
        if (mode == StorageMode.Uninitialized) {
            _setStorageMode(name, StorageMode.OnChain);
        }
        _putChunkFromCalldata(keccak256(name), chunkId, data, msg.value);
    }

    function writeChunks(
        bytes memory name,
        uint256[] memory chunkIds,
        uint256[] memory sizes
    ) public onlyOwner override payable {
        require(isSupportBlob(), "The current network does not support blob upload");

        StorageMode mode = getStorageMode(name);
        require(mode == StorageMode.Uninitialized || mode == StorageMode.Blob, "Invalid storage mode");
        if (mode == StorageMode.Uninitialized) {
            _setStorageMode(name, StorageMode.Blob);
        }
        _putChunks(keccak256(name), chunkIds, sizes);
    }

    function readChunk(bytes memory name, uint256 chunkId) public view virtual override returns (bytes memory, bool) {
        StorageMode mode = getStorageMode(name);
        if (mode == StorageMode.Blob) {
            return _getChunkFromBlob(keccak256(name), chunkId);
        } else if (mode == StorageMode.OnChain) {
            return _getChunk(keccak256(name), chunkId);
        }
        return (new bytes(0), false);
    }

    function chunkSize(bytes memory name, uint256 chunkId) public view virtual override returns (uint256, bool) {
        StorageMode mode = getStorageMode(name);
        if (mode == StorageMode.Blob) {
            return _chunkSizeFromBlob(keccak256(name), chunkId);
        } else if (mode == StorageMode.OnChain) {
            return _chunkSize(keccak256(name), chunkId);
        }
        return (0, false);
    }

    function removeChunk(bytes memory name, uint256 chunkId) public virtual onlyOwner override returns (bool) {
        StorageMode mode = getStorageMode(name);
        if (mode == StorageMode.Blob) {
            return _removeChunkFromBlob(keccak256(name), chunkId);
        } else if (mode == StorageMode.OnChain) {
            return _removeChunk(keccak256(name), chunkId);
        }
        return false;
    }

    function truncate(bytes memory name, uint256 chunkId) public virtual onlyOwner override returns (uint256) {
        StorageMode mode = getStorageMode(name);
        if (mode == StorageMode.Blob) {
            return _removeFromBlob(keccak256(name), chunkId);
        } else if (mode == StorageMode.OnChain) {
            return _remove(keccak256(name), chunkId);
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
        StorageMode mode = getStorageMode(name);
        if (mode == StorageMode.Blob) {
            return _getChunkHashFromBlob(keccak256(name), chunkId);
        } else if (mode == StorageMode.OnChain) {
            (bytes memory localData,) = readChunk(name, chunkId);
            return keccak256(localData);
        }
        return 0;
    }

    function getChunkHashes(bytes memory name, uint256[] memory chunkIds) public view returns (bytes32[] memory hashes) {
        bytes32 key = keccak256(name);
        StorageMode mode = storageModes[key];

        hashes = new bytes32[](chunkIds.length);
        for (uint8 i = 0; i < chunkIds.length; i++) {
            if (mode == StorageMode.Blob) {
                hashes[i] = _getChunkHashFromBlob(key, chunkIds[i]);
            } else if (mode == StorageMode.OnChain) {
                (bytes memory localData,) = _getChunk(key, chunkIds[i]);
                hashes[i] = keccak256(localData);
            }
        }
    }

    function getUploadInfo(bytes memory name) public view returns (StorageMode mode, uint256 count, uint256 payment) {
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
