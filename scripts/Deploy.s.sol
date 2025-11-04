// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "contracts/FlatDirectoryFactory.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address storageAddress;
        if (block.chainid == 11155111) { // Sepolia
            storageAddress = 0xAb3d380A268d088BA21Eb313c1C23F3BEC5cfe93;
        } else if (block.chainid == 3335) { // quarkchain L2 network
            storageAddress = 0x64003adbdf3014f7E38FC6BE752EB047b95da89A;
        } else if (block.chainid == 1) { // etherum mainnet
            storageAddress = 0xf0193d6E8fc186e77b6E63af4151db07524f6a7A;
        } else {
            storageAddress = address(0);
        }

        FlatDirectoryFactory factory = new FlatDirectoryFactory(storageAddress);
        console.log("Deployed FlatDirectoryFactory at:", address(factory));

        vm.stopBroadcast();
    }
}
