import hardhat,{ ethers } from "hardhat";
async function main() {
    const [owner, gov] = await ethers.getSigners();
    const _BASEFEE = '100000000000000000';
    const _GASPRICELINK = '1000000000';
    const _FUND_AMOUNT = '1000000000000000000';
    const _KEYHASH = '0x114f3da0a805b6a67d6e9cd2ec746f7028f1b7376365af575cfea3550dd1aa04';
    const subscriptionId = 0;
    await hardhat.run("compile");

    //deploy custom USDC
    const USDC = await ethers.getContractFactory("USDC");
    const usdc = await USDC.deploy();
    console.log(`[USDC] Address : ${usdc.address}`);

    //deploy ChainLink VRF Mock
    const Coordinator = await ethers.getContractFactory("VRFCoordinatorV2Mock");
    const coordinator = await Coordinator.deploy(_BASEFEE, _GASPRICELINK);
    await coordinator.deployed();
    console.log(`[VRFCoordinatorV2Mock] Address: ${coordinator.address}`);

    //create subscription and fund the subscription
    const currentSub = await coordinator.createSubscription();
    const currentSub2 = await coordinator.fundSubscription(subscriptionId, _FUND_AMOUNT, {gasLimit:'20000000'});
    console.log(`[VRFCoordinatorV2Mock] 订阅id: 1`);
    console.log(`[VRFCoordinatorV2Mock] 订阅资金: ${ethers.utils.formatEther(_FUND_AMOUNT)} LINK`);

    //deploy Raffle Rush
    const RuffleRush = await ethers.getContractFactory("RaffleRush");
    const raffleRush = await RuffleRush.deploy(
        subscriptionId,
        coordinator,
        _KEYHASH,
        owner.address,
        {gasLimit:'5000000'});
    await raffleRush.deployed();
    console.log(`[RuffleRush] Address : ${raffleRush.address}`);

    //ChainLink VRF add Raffle consumer
    await coordinator.addConsumer(subscriptionId, raffleRush.address);
    console.log(`[Coordinator] addConsumer : Success`);
}
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });