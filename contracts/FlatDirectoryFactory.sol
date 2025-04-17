// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./FlatDirectory.sol";

contract FlatDirectoryFactory {
    event FlatDirectoryCreated(address);

    function createOP(address _ethStorage) public returns (address) {
        uint32 dataSize = (4 * 31 + 3) * 1024 - 4;
        return _create(0, dataSize, _ethStorage);
    }

    function create(uint32 _size, address _ethStorage) public returns (address) {
        return _create(0, _size, _ethStorage);
    }

    function createOptimized(uint32 _size, address _ethStorage) public returns (address) {
        return _create(220, _size, _ethStorage);
    }

    function _create(uint8 _slotLimit, uint32 _size, address _ethStorage) private returns (address) {
        FlatDirectory fd = new FlatDirectory(_slotLimit, _size, _ethStorage);
        emit FlatDirectoryCreated(address(fd));
        return address(fd);
    }
}
