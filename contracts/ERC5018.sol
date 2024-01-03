// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IERC5018.sol";
import "./LargeStorageManager.sol";
import "./BlobStorageManager.sol";

contract ERC5018 is IERC5018, LargeStorageManager, BlobStorageManager  {

    enum FileMode {
        Uninitialized,
        CallData,
        Blob
    }
    mapping(bytes32 => FileMode) fileModes;

    constructor(
        uint8 slotLimit,
        uint32 fileSize,
        address storageAddress
    ) LargeStorageManager(slotLimit) BlobStorageManager(fileSize, storageAddress){}

    function getFileMode(bytes memory name) public view returns(FileMode) {
        return fileModes[keccak256(name)];
    }

    function setFileMode(bytes memory name, FileMode mode) public {
        fileModes[keccak256(name)] = mode;
    }

    // Large storage methods
    function write(bytes memory name, bytes calldata data) public onlyOwner payable virtual override {
        // TODO: support multiple chunks
        FileMode mode = getFileMode(name);
        require(mode == FileMode.Uninitialized || mode == FileMode.CallData, "Invalid file upload mode");
        setFileMode(name, FileMode.CallData);
        return _putChunkFromCalldata(keccak256(name), 0, data, msg.value);
    }

    function read(bytes memory name) public view virtual override returns (bytes memory, bool) {
        if (getFileMode(name) == FileMode.Blob) {
            return _getFromBlob(keccak256(name));
        }
        return _get(keccak256(name));
    }

    function size(bytes memory name) public view virtual override returns (uint256, uint256) {
        if (getFileMode(name) == FileMode.Blob) {
            return _sizeFromBlob(keccak256(name));
        }
        return _size(keccak256(name));
    }

    function remove(bytes memory name) public virtual override onlyOwner returns (uint256) {
        if (getFileMode(name) == FileMode.Blob) {
            return _removeFromBlob(keccak256(name), 0);
        }
        return _remove(keccak256(name), 0);
    }

    function countChunks(bytes memory name) public view virtual override returns (uint256) {
        if (getFileMode(name) == FileMode.Blob) {
            return _countChunksFromBlob(keccak256(name));
        }
        return _countChunks(keccak256(name));
    }

    // Chunk-based large storage methods
    function writeChunk(
        bytes memory name,
        uint256 chunkId,
        bytes calldata data
    ) public payable onlyOwner virtual override {
        FileMode mode = getFileMode(name);
        require(mode == FileMode.Uninitialized || mode == FileMode.CallData, "Invalid file upload mode");
        if (mode == FileMode.Uninitialized) {
            setFileMode(name, FileMode.CallData);
        }
        _putChunkFromCalldata(keccak256(name), chunkId, data, msg.value);
    }

    function writeChunks(
        bytes memory name,
        uint256[] memory chunkIds,
        uint256[] memory sizes
    ) public onlyOwner override payable {
        FileMode mode = getFileMode(name);
        require(mode == FileMode.Uninitialized || mode == FileMode.Blob, "Invalid file upload mode");
        if (mode == FileMode.Uninitialized) {
            setFileMode(name, FileMode.Blob);
        }
        _putChunks(keccak256(name), chunkIds, sizes);
    }

    function readChunk(bytes memory name, uint256 chunkId) public view virtual override returns (bytes memory, bool) {
        if (getFileMode(name) == FileMode.Blob) {
            return _getChunkFromBlob(keccak256(name), chunkId);
        }
        return _getChunk(keccak256(name), chunkId);
    }

    function chunkSize(bytes memory name, uint256 chunkId) public view virtual override returns (uint256, bool) {
        if (getFileMode(name) == FileMode.Blob) {
            return _chunkSizeFromBlob(keccak256(name), chunkId);
        }
        return _chunkSize(keccak256(name), chunkId);
    }

    function removeChunk(bytes memory name, uint256 chunkId) public virtual onlyOwner override returns (bool) {
        if (getFileMode(name) == FileMode.Blob) {
            return _removeChunkFromBlob(keccak256(name), chunkId);
        }
        return _removeChunk(keccak256(name), chunkId);
    }

    function truncate(bytes memory name, uint256 chunkId) public virtual onlyOwner override returns (uint256) {
        if (getFileMode(name) == FileMode.Blob) {
            return _removeFromBlob(keccak256(name), chunkId);
        }
        return _remove(keccak256(name), chunkId);
    }

    function refund() public onlyOwner override {
        payable(owner()).transfer(address(this).balance);
    }

    function destruct() public onlyOwner override {
        selfdestruct(payable(owner()));
    }

    function getChunkHash(bytes memory name, uint256 chunkId) public override view returns (bytes32) {
        if (getFileMode(name) == FileMode.Blob) {
            return _getChunkHashFromBlob(keccak256(name), chunkId);
        }
        (bytes memory localData,) = readChunk(name, chunkId);
        return keccak256(localData);
    }
}
