// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "./FlatDirectory.sol";

contract FlatDirectoryFactory {
    event FlatDirectoryCreated(address);

    address public ethStorage;

    constructor(address _ethStorage) {
        ethStorage = _ethStorage;
    }

    function create() public returns (address) {
        uint32 dataSize = (4 * 31 + 3) * 1024 - 4;
        return _create(0, dataSize);
    }

    function createWithSize(uint32 _size) public returns (address) {
        return _create(0, _size);
    }

    function createWithOptimized(uint32 _size) public returns (address) {
        return _create(220, _size);
    }

    function _create(uint8 _slotLimit, uint32 _size) private returns (address) {
        FlatDirectory fd = new FlatDirectory(_slotLimit, _size, ethStorage);
        emit FlatDirectoryCreated(address(fd));
        fd.transferOwnership(msg.sender);
        return address(fd);
    }
}
