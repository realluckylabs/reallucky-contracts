import "./tasks";
import "hardhat-gas-reporter";
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import { buildHardhatNetworkAccounts, getPKs } from "./utils/configInit";
const accounts = getPKs();
const hardhatNetworkAccounts = buildHardhatNetworkAccounts(accounts);

const config: HardhatUserConfig = {
  defaultNetwork: "bsctest",
  networks: {
    bsctest: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545",
      chainId: 97,
      // gasPrice: 20000000000,
      accounts,
    },
    hardhat: {
      // accounts visible to hardhat network used by `hardhat node --fork` (yarn net <chainName>)
      gasPrice:3000000000,
      accounts: hardhatNetworkAccounts,
    },
    bsc: {
      url: process.env.BSC_RPC || "https://rpc.ankr.com/bsc",
      chainId: 56,
      accounts,
    },
    localhost: {
      url: "http://127.0.0.1:8545",
      timeout: 300000,
      gasPrice:3000000000,
      accounts: "remote",
    },
  },
  solidity: {
    compilers: [
      {
        version: "0.8.17",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
          viaIR: false,
        },
      },
    ],
  },
  paths: {
    sources: "./contracts",
  },
  gasReporter: {
    enabled: true,
    showTimeSpent: true,
    // onlyCalledMethods: false,
    currency: "USD",//You can use other fiat symbol e.g. EUR GBP etc.
    token: 'BNB',//You can replace with selected chain's native token or other alt-coin
    coinmarketcap:'Your coinmarketcap.com api-key',
    gasPriceApi:'https://api.bscscan.com/api?module=proxy&action=eth_gasPrice&apikey=[Your bscscan.com api-key]'
  },
  mocha: {
    timeout: 100000000
  },
};

export default config;
