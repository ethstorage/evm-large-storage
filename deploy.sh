#!/bin/bash
source .env

forge build

forge script scripts/Deploy.s.sol:Deploy \
  --broadcast \
  --rpc-url https://rpc.beta.testnet.l2.quarkchain.io:8545
