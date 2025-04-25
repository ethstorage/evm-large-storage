// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC5018 {
    enum StorageMode {
        Uninitialized,
        OnChain,
        Blob
    }

    struct FileChunk {
        bytes name;
        uint256[] chunkIds;
    }

    // Large storage methods
    function write(bytes memory name, bytes memory data) external payable;

    function read(bytes memory name) external view returns (bytes memory, bool);

    // return (size, # of chunks)
    function size(bytes memory name) external view returns (uint256, uint256);

    function remove(bytes memory name) external returns (uint256);

    function countChunks(bytes memory name) external view returns (uint256);

    /// @notice This function is deprecated and will be removed in future versions.
    /// @dev Use `writeChunkByCalldata` instead.
    function writeChunk(bytes memory name, uint256 chunkId, bytes memory data) external payable;

    // Chunk-based large storage methods
    function writeChunkByCalldata(bytes memory name, uint256 chunkId, bytes memory data) external payable;

    /// @notice This function is deprecated and will be removed in future versions.
    /// @dev Use `writeChunksByBlobs` instead.
    function writeChunks(bytes memory name, uint256[] memory chunkIds, uint256[] memory sizes) external payable;

    function writeChunksByBlobs(bytes memory name, uint256[] memory chunkIds, uint256[] memory sizes)
        external
        payable;

    function readChunk(bytes memory name, uint256 chunkId) external view returns (bytes memory, bool);

    function chunkSize(bytes memory name, uint256 chunkId) external view returns (uint256, bool);

    function removeChunk(bytes memory name, uint256 chunkId) external returns (bool);

    function truncate(bytes memory name, uint256 chunkId) external returns (uint256);

    function refund() external;

    function destruct() external;

    function getChunkHash(bytes memory name, uint256 chunkId) external view returns (bytes32);

    function getChunkHashesBatch(FileChunk[] memory fileChunks) external view returns (bytes32[] memory);

    function getChunkCountsBatch(bytes[] memory names) external view returns (uint256[] memory);

    function getUploadInfo(bytes memory name)
        external
        view
        returns (StorageMode mode, uint256 chunkCount, uint256 storageCost);
}
