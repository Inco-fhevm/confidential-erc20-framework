# Confidential ERC20 Framework
The confidential ERC20 Framework transforms ERC20 tokens into a confidential form that conceals balances and transaction amounts, with optional viewing and transfer rules to meet regulatory obligations or enhance programmatic risk management. While sender-receiver linkage remains, Confidential ERC20 balances privacy with risk management using an encryption-based approach, specifically fully homomorphic encryption (FHE), allowing operations on encrypted data without decryption.

This implementation is based on the collaborative research between [Inco](https://www.inco.org/) and [Circle Research](https://www.circle.com/en/circle-research). For more information, see the [whitepaper](https://github.com/Inco-fhevm/confidential-erc20-framework/blob/main/whitepaper.pdf).

Note: This repository is not audited and is intended solely as a proof of concept.

## Usage

### Pre Requisites

Install [pnpm](https://pnpm.io/installation)

Before being able to run any command, you need to create a `.env` file and set a BIP-39 compatible mnemonic as an
environment variable. You can follow the example in `.env.example` and start with the following command:

```sh
cp .env.example .env
```

If you don't already have a mnemonic, you can use this [website](https://iancoleman.io/bip39/) to generate one.

Then, proceed with installing dependencies - please **_make sure to use Node v20_** or more recent or this will fail:

```sh
pnpm install
```

### Choose the right network path

- Use this repository when you want to work with the Confidential ERC20 framework on **Rivest testnet**.
- If your target is **Inco Lightning (Base Sepolia)**, start from the dedicated template: [Inco Lite Template](https://github.com/Inco-fhevm/inco-lite-template).
- Keeping the network/tooling path explicit helps avoid mixing setup steps between Rivest and Lightning environments.

## For development on Rivest testnet

After installation run the pre-launch script to setup the environment:

```sh
sh pre-launch.sh
```
this generates the necessary precompile ABI files.

To deploy the contracts on the rivest network, run the following command:

```sh
pnpm deploy:contracts --network rivest
```
To run the tests on the rivest network, run the following command:

```sh
pnpm test:rivest
```
#### Resources

- Block explorer: [https://explorer.rivest.inco.org/](https://explorer.rivest.inco.org/);
- Faucet: [https://faucet.rivest.inco.org/](https://faucet.rivest.inco.org/);
- RPC endpoint: [https://validator.rivest.inco.org](https://validator.rivest.inco.org).
- Gateway endpoint: [https://gateway.rivest.inco.org](https://gateway.rivest.inco.org).
