// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./FlatDirectory.sol";

contract FlatDirectoryFactory {
    event FlatDirectoryCreated(address);

    function create(uint8 _size, address _ethStorage) public returns (address) {
        FlatDirectory fd = new FlatDirectory(0, _size, _ethStorage);
        fd.transferOwnership(msg.sender);
        emit FlatDirectoryCreated(address(fd));
        return address(fd);
    }

    function createOptimized(uint8 _size, address _ethStorage) public returns (address) {
        FlatDirectory fd = new FlatDirectory(220, _size, _ethStorage);
        fd.transferOwnership(msg.sender);
        emit FlatDirectoryCreated(address(fd));
        return address(fd);
    }
}
