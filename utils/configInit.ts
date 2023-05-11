import dotenv from "dotenv";
dotenv.config();

import { BigNumber, ethers } from "ethers";
import { HardhatNetworkAccountUserConfig } from "hardhat/src/types/config";

export const startingEtherPerAccount = ethers.utils.parseUnits(BigNumber.from(1_000_000_000).toString(), "ether");

export const getPKs = () => {
  let deployerAccount, govAccount;

  // PKs without `0x` prefix
  if (process.env.DEPLOYER_PK) deployerAccount = process.env.DEPLOYER_PK;
  if (process.env.GOV_PK) govAccount = process.env.GOV_PK;
  const accounts = [deployerAccount, govAccount].filter(pk => !!pk) as string[];
  for (let i = 0; i < 10; i ++){

    if(eval(`process.env.TEST_${i+1}_PK`)){
      accounts.push(eval(`process.env.TEST_${i+1}_PK`));
    }
  }
  return accounts;
};

export const buildHardhatNetworkAccounts = (accounts: string[]) => {
  
  const hardhatAccounts = accounts.map(pk => {
    // hardhat network wants 0x prefix in front of PK
    const accountConfig: HardhatNetworkAccountUserConfig = {
      privateKey: pk,
      balance: startingEtherPerAccount.toString(),
    };
    return accountConfig;
  });
  return hardhatAccounts;
};
