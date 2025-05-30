// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "./core/ERC5018.sol";

contract FlatDirectory is ERC5018 {
    bytes public defaultFile = "";

    constructor(uint8 slotLimit, uint32 maxChunkSize, address storageAddress)
        ERC5018(slotLimit, maxChunkSize, storageAddress)
    {}

    function resolveMode() external pure virtual returns (bytes32) {
        return "manual";
    }

    fallback(bytes calldata pathinfo) external returns (bytes memory) {
        bytes memory content;
        if (pathinfo.length == 0) {
            // TODO: redirect to "/"?
            return bytes("");
        } else if (pathinfo[0] != 0x2f) {
            // Should not happen since manual mode will have prefix "/" like "/....."
            return bytes("incorrect path");
        }

        if (pathinfo[pathinfo.length - 1] == 0x2f) {
            (content,) = read(bytes.concat(pathinfo[1:], defaultFile));
        } else {
            (content,) = read(pathinfo[1:]);
        }

        StorageHelper.returnBytesInplace(content);
    }

    function setDefault(bytes memory _defaultFile) public virtual onlyOwner {
        defaultFile = _defaultFile;
    }
}
