// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./LargeStorageManager.sol";

contract EthStorageContractTest is LargeStorageManager(0) {

    enum DecodeType {
        RawData,
        PaddingPer31Bytes
    }

    event PutBlob(bytes32 key, uint256 blobIdx, uint256 length);

    // implement
    function putBlob(bytes32 key, uint256 blobIdx, uint256 length) external payable {
        emit PutBlob(key, blobIdx, length);
    }

    // write real data
    function writeBlobChunk(bytes32 key, uint256 chunkId, bytes calldata data) public payable virtual {
        return _putChunkFromCalldata(key, chunkId, data, msg.value);
    }

    function remove(bytes32 key) external {
        _remove(key, 0);
    }

    function get(bytes32 key, DecodeType decodeType, uint256 off, uint256 len) external view returns (bytes memory data) {
        (data,) = _get(key);
    }

    function size(bytes32 key) external view returns (uint256 s) {
        (s,) = _size(key);
    }

    function hash(bytes32 key) external view returns (bytes24) {
        (bytes memory localData,) = _get(key);
        return bytes24(keccak256(localData));
    }

    function upfrontPayment() external view returns (uint256) {
        return 0;
    }
}
