#!/bin/bash
source .env

forge script script/Deploy.s.sol:Deploy \
  --broadcast \
  --slow \
  --legacy \
  --rpc-url https://rpc.beta.testnet.l2.quarkchain.io:8545
