// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IERC5018.sol";
import "../interfaces/ISemver.sol";

import "./LargeStorageManager.sol";
import "./BlobStorageManager.sol";

contract ERC5018 is LargeStorageManager, BlobStorageManager, IERC5018, ISemver {
    mapping(bytes32 => StorageMode) storageModes;

    constructor(uint8 slotLimit, uint32 maxChunkSize, address storageAddress)
        LargeStorageManager(slotLimit)
        BlobStorageManager(maxChunkSize, storageAddress)
    {}

    /// @notice Semantic version.
    /// @custom:semver 1.0.0
    function version() public pure virtual returns (string memory) {
        return "1.0.0";
    }

    function getStorageMode(bytes memory name) public view returns (StorageMode) {
        return storageModes[keccak256(name)];
    }

    // Large storage methods
    function write(bytes memory name, bytes calldata data) public payable virtual override onlyOwner {
        // TODO: support multiple chunks
        return writeChunk(name, 0, data);
    }

    function read(bytes memory name) public view virtual override returns (bytes memory, bool) {
        (bytes32 key, StorageMode mode) = _getModeAndKey(name);
        if (mode == StorageMode.Blob) {
            return _getFromBlob(key);
        } else if (mode == StorageMode.OnChain) {
            return _get(key);
        }
        return (new bytes(0), false);
    }

    function size(bytes memory name) public view virtual override returns (uint256, uint256) {
        (bytes32 key, StorageMode mode) = _getModeAndKey(name);
        if (mode == StorageMode.Blob) {
            return _sizeFromBlob(key);
        } else if (mode == StorageMode.OnChain) {
            return _size(key);
        }
        return (0, 0);
    }

    function remove(bytes memory name) public virtual override onlyOwner returns (uint256) {
        (bytes32 key, StorageMode mode) = _getModeAndKey(name);
        storageModes[key] = StorageMode.Uninitialized;
        if (mode == StorageMode.Blob) {
            return _removeFromBlob(key, 0);
        } else if (mode == StorageMode.OnChain) {
            return _remove(key, 0);
        }
        return 0;
    }

    function countChunks(bytes memory name) public view virtual override returns (uint256) {
        (bytes32 key, StorageMode mode) = _getModeAndKey(name);
        if (mode == StorageMode.Blob) {
            return _countChunksFromBlob(key);
        } else if (mode == StorageMode.OnChain) {
            return _countChunks(key);
        }
        return 0;
    }

    /// @notice This function is deprecated and will be removed in future versions.
    /// @dev Use `writeChunkByCalldata` instead.
    function writeChunk(bytes memory name, uint256 chunkId, bytes calldata data)
        public
        payable
        virtual
        override
        onlyOwner
    {
        writeChunkByCalldata(name, chunkId, data);
    }

    function writeChunkByCalldata(bytes memory name, uint256 chunkId, bytes calldata data)
        public
        payable
        virtual
        override
        onlyOwner
    {
        (bytes32 key, StorageMode mode) = _getModeAndKey(name);
        require(mode == StorageMode.Uninitialized || mode == StorageMode.OnChain, "Invalid storage mode");
        if (mode == StorageMode.Uninitialized) {
            storageModes[key] = StorageMode.OnChain;
        }
        _putChunkFromCalldata(key, chunkId, data, msg.value);
    }

    /// @notice This function is deprecated and will be removed in future versions.
    /// @dev Use `writeChunksByBlobs` instead.
    function writeChunks(bytes memory name, uint256[] memory chunkIds, uint256[] memory sizes)
        public
        payable
        override
        onlyOwner
    {
        writeChunksByBlobs(name, chunkIds, sizes);
    }

    function writeChunksByBlobs(bytes memory name, uint256[] memory chunkIds, uint256[] memory sizes)
        public
        payable
        override
        onlyOwner
    {
        require(isSupportBlob(), "The current network does not support blob upload");

        (bytes32 key, StorageMode mode) = _getModeAndKey(name);
        require(mode == StorageMode.Uninitialized || mode == StorageMode.Blob, "Invalid storage mode");
        if (mode == StorageMode.Uninitialized) {
            storageModes[key] = StorageMode.Blob;
        }
        _putChunks(key, chunkIds, sizes);
    }

    function readChunk(bytes memory name, uint256 chunkId) public view virtual override returns (bytes memory, bool) {
        (bytes32 key, StorageMode mode) = _getModeAndKey(name);
        if (mode == StorageMode.Blob) {
            return _getChunkFromBlob(key, chunkId);
        } else if (mode == StorageMode.OnChain) {
            return _getChunk(key, chunkId);
        }
        return (new bytes(0), false);
    }

    function chunkSize(bytes memory name, uint256 chunkId) public view virtual override returns (uint256, bool) {
        (bytes32 key, StorageMode mode) = _getModeAndKey(name);
        if (mode == StorageMode.Blob) {
            return _chunkSizeFromBlob(key, chunkId);
        } else if (mode == StorageMode.OnChain) {
            return _chunkSize(key, chunkId);
        }
        return (0, false);
    }

    function removeChunk(bytes memory name, uint256 chunkId) public virtual override onlyOwner returns (bool) {
        (bytes32 key, StorageMode mode) = _getModeAndKey(name);
        if (mode == StorageMode.Blob) {
            return _removeChunkFromBlob(key, chunkId);
        } else if (mode == StorageMode.OnChain) {
            return _removeChunk(key, chunkId);
        }
        return false;
    }

    function truncate(bytes memory name, uint256 chunkId) public virtual override onlyOwner returns (uint256) {
        (bytes32 key, StorageMode mode) = _getModeAndKey(name);
        if (mode == StorageMode.Blob) {
            return _removeFromBlob(key, chunkId);
        } else if (mode == StorageMode.OnChain) {
            return _remove(key, chunkId);
        }
        return 0;
    }

    function refund() public override onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function destruct() public override onlyOwner {
        selfdestruct(payable(owner()));
    }

    function getChunkHash(bytes memory name, uint256 chunkId) public view override returns (bytes32) {
        (bytes32 key, StorageMode mode) = _getModeAndKey(name);
        if (mode == StorageMode.Blob) {
            return _getChunkHashFromBlob(key, chunkId);
        } else if (mode == StorageMode.OnChain) {
            (bytes memory localData,) = _getChunk(key, chunkId);
            return keccak256(localData);
        }
        return 0;
    }

    function getChunkHashesBatch(FileChunk[] memory fileChunks) external view returns (bytes32[] memory) {
        uint256 totalChunks = 0;

        for (uint256 i = 0; i < fileChunks.length; i++) {
            totalChunks += fileChunks[i].chunkIds.length;
        }

        bytes32[] memory hashes = new bytes32[](totalChunks);
        uint256 index = 0;
        for (uint256 i = 0; i < fileChunks.length; i++) {
            for (uint256 j = 0; j < fileChunks[i].chunkIds.length; j++) {
                hashes[index] = getChunkHash(fileChunks[i].name, fileChunks[i].chunkIds[j]);
                index++;
            }
        }
        return hashes;
    }

    function getChunkCountsBatch(bytes[] memory names) external view returns (uint256[] memory) {
        uint256[] memory counts = new uint256[](names.length);
        for (uint256 i = 0; i < names.length; i++) {
            counts[i] = countChunks(names[i]);
        }
        return counts;
    }

    function getUploadInfo(bytes memory name)
        public
        view
        override
        returns (StorageMode mode, uint256 chunkCount, uint256 storageCost)
    {
        bytes32 key;
        (key, mode) = _getModeAndKey(name);

        if (mode == StorageMode.Blob) {
            chunkCount = _countChunksFromBlob(key);
        } else if (mode == StorageMode.OnChain) {
            chunkCount = _countChunks(key);
        } else {
            chunkCount = 0;
        }

        storageCost = address(storageContract) != address(0) ? upfrontPayment() : 0;
    }

    function _getModeAndKey(bytes memory name) private view returns (bytes32 key, StorageMode mode) {
        key = keccak256(name);
        mode = storageModes[key];
    }
}
