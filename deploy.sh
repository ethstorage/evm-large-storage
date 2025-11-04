#!/bin/bash
source .env

forge build

forge script scripts/Deploy.s.sol:Deploy \
  --broadcast \
  --rpc-url http://65.108.230.142:8545/
