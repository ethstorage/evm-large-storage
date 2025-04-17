// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "contracts/FlatDirectory.sol";
import "contracts/FlatDirectoryFactory.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        uint8 slotLimit = 0;
        uint32 maxChunkSize = (4 * 31 + 3) * 1024 - 4;

        address storageAddress;
        if (block.chainid == 11155111) {// Sepolia
            storageAddress = 0x804C520d3c084C805E37A35E90057Ac32831F96f;
        } else if (block.chainid == 3335) {// quarkchain L2 network
            storageAddress = 0x64003adbdf3014f7E38FC6BE752EB047b95da89A;
        } else {
            storageAddress = address(0);
        }

        FlatDirectory dir = new FlatDirectory(slotLimit, maxChunkSize, storageAddress);
        console.log("Deployed FlatDirectory at:", address(dir));

        FlatDirectoryFactory factory = new FlatDirectoryFactory();
        console.log("Deployed FlatDirectoryFactory at:", address(factory));

        vm.stopBroadcast();
    }
}
