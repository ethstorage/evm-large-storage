// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./FlatDirectory.sol";

contract FlatDirectoryFactory {
    event FlatDirectoryCreated(address);

    function create() public returns (address) {
        FlatDirectory fd = new FlatDirectory(0, 0, address(0));
        fd.transferOwnership(msg.sender);
        emit FlatDirectoryCreated(address(fd));
        return address(fd);
    }

    function createOptimized() public returns (address) {
        FlatDirectory fd = new FlatDirectory(220, 0, address(0));
        fd.transferOwnership(msg.sender);
        emit FlatDirectoryCreated(address(fd));
        return address(fd);
    }
}
