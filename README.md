# RaffleRush
[中文](README.zh_CN.md)
## Introduction

This is the smart contract code for the [reallucky.io](https://app.reallucky.io) project, which ensures a 100% match with the [deployed contract](https://bscscan.com/address/0xbbb1381e648c66ca10d2bb1ccea46993eef556c8) online, with no modification. At the same time, the source code of the contract has also been source code verified on [bscscan.com](https://bscscan.com/address/0xbbb1381e648c66ca10d2bb1ccea46993eef556c8#code).
## Deploy Details
Deployed on Binance Smart Chain

upgradeable version [In Use]
```dotenv
 ProxyAddress   = 0xaF6C809408d9EE1E70809e20ab7547Cf59ed811e
 AdminAddress   = 0x6cEdF5184096c6F41aBdc016A86F0853F47c2b34
 Implementation = 0xB8930c0b140923632d0D8489cB7EE07F28BE9ff6
```
*~~non-upgradeable Version [Deprecated]~~*

>~~0xbbb1381e648c66ca10d2bb1ccea46993eef556c8~~

## Getting Started

### Prerequisites

- Install Node.js, recommended version 18 or above
- Use npm or yarn package manager

## Initialize Environment

### Install hardhat and project dependencies
```shell
npm install -D
```
### Create an account environment file .env in the project root directory

```shell
DEPLOYER_PK='Your deployment account private key, without 0x'
GOV_PK='Your governance account private key, without 0x'
#There are a total of 10 test accounts, please complete them yourself
TEST_1_PK='Your test account 1 private key, without 0x'
...
TEST_10_PK='Your test account 10 private key, without 0x'
```

### If GasReport is enabled, please fill in the corresponding api key in hardat.config.ts
```shell
...
gasReporter: {
    ...
    coinmarketcap:'[Your coinmarketcap.com api-key]',
    gasPriceApi:'https://api.bscscan.com/api?module=proxy&action=eth_gasPrice&apikey=[Your bscscan.com api-key]'
    ...
}
...
```
## Usage

### Local testing

ChainLink VRF

>For local testing, you need to deploy the ChainLink VRF simulated contract yourself and execute the callback operation yourself. For specific operations, see the [official documentation](https://docs.chain.link/vrf/v2/subscription/examples/test-locally).

Start the local bsc test environment
```shell
#Open a terminal in the project root directory and execute
npx hardhat node --fork bsc
```
Run commands
```shell
#Open a second terminal in the project root directory, you can run hardhat commands

#Compile sol files
npx hardhat compile

#Execute ts script under scripts, use local environment
npx hardhat run ./scripts/deploy_raffle_upgradeable.ts --network localhost

#If you want to use other environments, just specify the environment alias after --network, environment aliases are defined in the config of hardhat.config.ts
#For example, if you want to deploy and execute the contract on bsctest, you can run
npx hardhat run ./scripts/deploy_raffle_upgradeable.ts --network bsctest
```
Run test script
```shell
# Open a third terminal in the project root directory, you can run hardhat test commands
# Execute ts script in test, use local environment
npx hardhat test ./test/RaffleRush.ts --network localhost

# If you want to use other environments, just specify the environment alias after --network, environment aliases are defined in the config of hardhat.config.ts
# For example, if you want to test on bsctest, you can run
npx hardhat test ./test/RaffleRush.ts --network bsctest
```
### Mainnet deployment

**Before deployment**

>You need to create a subscription in ChainLink’s background, then fill in the subscription id and coordinator address in the deployment scriptscripts/deploy_raffle_upgradeable.ts  
>[Official documentation](https://docs.chain.link/vrf/v2/subscription)

Deploy
```shell
npx hardhat run ./scripts/deploy_raffle_upgradeable.ts --network bsc
```
The proxy address printed on the console is the contract address you deployed this time.

**After deployment**

>Remember to add the proxy address to ChainLink’s consumer list