import hardhat,{ ethers } from "hardhat";
async function main() {
    const [owner, gov] = await ethers.getSigners();
    const _KEYHASH = '0x114f3da0a805b6a67d6e9cd2ec746f7028f1b7376365af575cfea3550dd1aa04';//TODO Replaced with your preferred gas pattern
    await hardhat.run("compile");
    const subscriptionId = 0;//TODO Replaced with your own id
    const coordinator = '0xYourChainLinkCoordinatorAddress';//TODO Replaced with your own address
    const RuffleRush = await ethers.getContractFactory("RaffleRush");
    const raffleRush = await RuffleRush.deploy(
        subscriptionId,
        coordinator,
        _KEYHASH,
        gov.address,
        {gasLimit:'5000000'});
    await raffleRush.deployed();
    console.log(`[RuffleRush] Address : ${raffleRush.address}`);//TODO Remember to add consumer at ChainLink Backend
}
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });