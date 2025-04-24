// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "./FlatDirectory.sol";

contract FlatDirectoryFactory {
    event FlatDirectoryCreated(address);

    function create(address _ethStorage) public returns (address) {
        uint32 dataSize = (4 * 31 + 3) * 1024 - 4;
        return _create(0, dataSize, _ethStorage);
    }

    function createWithSize(uint32 _size, address _ethStorage) public returns (address) {


        return _create(0,   _size, _ethStorage);
    }

    function createWithOptimized(uint32 _size, address _ethStorage) public returns (address) {
        return _create(220, _size, _ethStorage);
    }

    function _create(uint8 _slotLimit, uint32 _size, address _ethStorage) private returns (address) {
        FlatDirectory fd = new FlatDirectory(_slotLimit, _size, _ethStorage);
        emit FlatDirectoryCreated(address(fd));
        return address(fd);
    }
}
