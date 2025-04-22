// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract StorageSlotSelfDestructable {
    address public immutable owner;

    constructor() {
        owner = msg.sender;
    }

    function destruct() public {
        require(msg.sender == owner, "not from owner");
        selfdestruct(payable(msg.sender));
    }
}
