# Obol Staking

This repository contains the contract assembly, configuration and deployment scripts for the Obol Staking System.

The Obol Staking system includes a base staker contract, built on the Tally [Staker](https://github.com/withtally/staker) library, that manages user staking deposits and reward distribution to depositors.

It also includes a liquid staking component built on top of [stGOV](https://github.com/withtally/stGOV). The latter allows depositors to stake while maintaining a liquid, auto-compounding position.

## Usage

Clone the repo:

```
git clone git@github.com:withtally/obolstaking.git
cd obolstaking
```

Install the Foundry dependencies:

```
forge install
```

Deploy the contracts to Sepolia Testnet:

```
forge script script/SepoliaObolDeploy.s.sol --rpc-url=https://ethereum-sepolia-rpc.publicnode.com --broadcast --slow
```

*NOTE:* Mainnet deployment scripts are in progress
