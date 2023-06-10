import { ethers, upgrades } from "hardhat";
async function main() {
    const [owner, gov] = await ethers.getSigners();
    const _KEYHASH = '0x114f3da0a805b6a67d6e9cd2ec746f7028f1b7376365af575cfea3550dd1aa04';
    const subscriptionId = 0;//TODO Replaced with your own id
    const coordinator = '0xYourChainLinkCoordinatorAddress';//TODO Replaced with your own address

    const RRUV1 = await ethers.getContractFactory("RaffleRushUpgradeableV1");
    const rru = await upgrades.deployProxy(RRUV1, [subscriptionId,
        coordinator,
        _KEYHASH,
        owner.address,]);
    await rru.deployed();
    console.log("RRUV1 proxy address:", rru.address);
    console.log("RRUV1 admin:", await upgrades.erc1967.getAdminAddress(rru.address));
    console.log("RRUV1 implementation:", await upgrades.erc1967.getImplementationAddress(rru.address));
}
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });