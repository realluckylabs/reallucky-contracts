// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";

import "./RandomNumbersUpgradeable.sol";
import "./RaffleGovUpgradeable.sol";
import "./VRFConsumerBaseV2Upgradeable.sol";

contract RaffleRushUpgradeableV2 is Initializable, RaffleGovUpgradeable, VRFConsumerBaseV2Upgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using AddressUpgradeable for address;
    using AddressUpgradeable for address payable;
    using SafeMathUpgradeable for uint256;
    /**
    Active - 正常抽奖
    Claimable - 不可以抽奖，等待发起者赎回资金
    Claimed - 发起者已经赎回资金【结束】
    Frozen - 发起者没有赎回资金，且时间已经超过最后提款日，资金冻结【结束】
    */
    enum RaffleState {Active, Claimable, Claimed, Frozen}
    enum RaffleType {Default, Random, Normal, Fun, Others}
    struct Raffle {
        address owner;//发起人
        uint256 sum;//奖金总额
        uint256 min;//最小中奖金额
        uint256 picked;//已开奖金额
        address bonus;//奖品
        uint256 seed;//VRF返回的随机数
        string ipfsHash;
        uint64 winners;//中奖人数
        uint64 pickedIndex;//已开奖人数
        uint64 startAt;//抽奖发起时间
        uint64 deadline1;//发起人开奖窗口[startAt, deadline1 - startAt == 7 days]
        uint64 deadline2;//最后提款窗口[deadline1, deadline2]{deadline1 - deadline2 == 7 days}
        RaffleType rType;//开奖类型
        RaffleState rState;//抽奖状态
        uint256[] eUint;
        address[] eAddr;
        string[] eStr;
    }
    //用于ChainLink的回调
    struct Caller{
        address who;
        uint256 index;
    }
    //合约配置
    struct RaffleConfig {
        uint256 feeCap;
        uint256 feePerWinner;
        uint64 maxWinners;
        uint64 maxWithdrawDelay;
        uint64 maxDrawDelay;
    }
    //ChainLink 相关
    struct ChainLinkConfig {
        VRFCoordinatorV2Interface coordinator;
        uint256 lastRequestId;
        bytes32 keyHash;
        uint64 subscriptionId;
        uint32 callbackGasLimit;
        uint16 requestConfirmations;
        uint32 numWords;
    }

    ChainLinkConfig public chainLinkConfig;
    //合约
    RaffleConfig public raffleConfig;
    //所有的开奖信息
    mapping(address => Raffle[]) public raffles;
    mapping(uint256 => Caller) public callers;
    mapping(address => uint256) public assetAvailable;
    mapping(address => uint256) public assetLocked;

    event ReturnedRandomness(uint256 requestId, uint256[] randomWords);
    event RequestRandom(uint256 requestId, address who);
    event CreateRaffle(address sponsor, uint256 rid, uint256 sum, uint256 winners, RaffleType rType);
    event CleanRaffle(address executor, address sponsor, uint256 index, uint256 amount);
    event UserClaim(address who, address bonus, uint256 amount);
    event SetFee(uint256 fee);
    event SetMaxWithdrawDelay(uint256 delay);
    event SetMaxDrawDelay(uint256 delay);
    event Draw(address sponsor, uint256 rid, address who, uint256 amount);
    function initialize(
        uint64 _subscriptionId,
        address _vrfCoordinator,
        bytes32 _keyHash,
        address _gov
    ) public initializer {
        RaffleGovUpgradeable.raffleInit(_gov);
        VRFConsumerBaseV2Upgradeable.vrfInit(_vrfCoordinator);
        chainLinkConfig.coordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        chainLinkConfig.keyHash = _keyHash;
        chainLinkConfig.subscriptionId = _subscriptionId;
        chainLinkConfig.callbackGasLimit = 100000;
        chainLinkConfig.requestConfirmations = 3;
        chainLinkConfig.numWords = 1;

        raffleConfig.feeCap = 88000 gwei;
        raffleConfig.feePerWinner = 0 gwei;
        raffleConfig.maxWinners = 200;
        raffleConfig.maxWithdrawDelay = 604800;
        raffleConfig.maxDrawDelay = 604800;
    }
    function isTypeValid(RaffleType _type) internal pure returns (bool) {
        return _type == RaffleType.Random || _type == RaffleType.Normal || _type == RaffleType.Fun;
    }
    function createRaffle(
        address _bonus,
        uint256 _sum,
        uint64 _winners,
        RaffleType _rType,
        uint256 _min,
        uint64 _deadline1
    ) public payable{

        if(_winners > raffleConfig.maxWinners){
            revert('!winners');
        }

        if(msg.sender.isContract()){
            revert('!EOA');
        }
        //Approve Check
        if(IERC20Upgradeable(_bonus).allowance(msg.sender, address(this)) < _sum){
            revert('!approve');
        }
        //发起者账户余额要大于_sum
        if(IERC20Upgradeable(_bonus).balanceOf(msg.sender) < _sum){
            revert('Insufficient amount!');
        }
        if(msg.value < raffleConfig.feePerWinner * _winners){
            revert('!fee');
        }
        require(isTypeValid(_rType) == true, "!rType");
        require(_deadline1 > block.timestamp && _deadline1 - block.timestamp <= raffleConfig.maxDrawDelay, "!delay");
        if(raffleConfig.feePerWinner > 0){
            payable(govAddress).sendValue(msg.value);
        }
        //增加可消费额度
        IERC20Upgradeable(_bonus).safeIncreaseAllowance(address(this), _sum);
        //从发起者账户转账
        IERC20Upgradeable(_bonus).safeTransferFrom(msg.sender, address(this), _sum);

        //给用户新增一个抽奖实例
        raffles[msg.sender].push(Raffle({
            owner: msg.sender,
            bonus: _bonus,
            sum: _sum,
            picked: 0,
            pickedIndex: 0,
            winners: _winners,
            rType: _rType,
            min: _min,
            startAt: uint64(block.timestamp),
            deadline1: _deadline1,
            deadline2: _deadline1 + raffleConfig.maxWithdrawDelay,
            seed: 0,
            rState: RaffleState.Active,
            ipfsHash:''
            ,eUint: new uint256 [](0)
            ,eAddr: new address [](0)
            ,eStr: new string [](0)
        }));
        require(raffles[msg.sender].length > 0, "raffles can't be empty!!");
        if(_rType == RaffleType.Random){
            chainLinkConfig.lastRequestId = chainLinkConfig.coordinator.requestRandomWords(
                chainLinkConfig.keyHash,
                chainLinkConfig.subscriptionId,
                chainLinkConfig.requestConfirmations,
                chainLinkConfig.callbackGasLimit,
                chainLinkConfig.numWords
            );
            //记录请求信息
            callers[chainLinkConfig.lastRequestId] = Caller({
                who:msg.sender,
                index:raffles[msg.sender].length - 1
            });
        }
        availableIncrease(_bonus, _sum);//增加available
        emit CreateRaffle(msg.sender, raffles[msg.sender].length - 1, _sum, _winners, _rType);
    }
    /**
    *回填中奖名单
    */
    function fillWinnerList(address sponsor, uint256 rid, string calldata ipfs) public {
        require(sponsor != address (0), "Invalid sponsor address");
        require(raffles[sponsor].length > rid, "No such raffle");
        require(raffles[sponsor][rid].owner != address (0), "Raffle owner invalid");
        require(raffles[sponsor][rid].deadline1 >= block.timestamp, "Draw date overdue");
        raffles[sponsor][rid].ipfsHash = ipfs;
    }
    /**
    * ChainLink回调
    */
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        //获取调用者信息，address和数组id
        if(callers[requestId].who != address(0)){
            if(raffles[callers[requestId].who].length > callers[requestId].index){
                raffles[callers[requestId].who][callers[requestId].index].seed = randomWords[0];
            }
            delete callers[requestId];//删除caller槽内的数据，节省gas
        }
        emit ReturnedRandomness(requestId, randomWords);
    }

    /**
    *获取中奖号码
    */
    function getRaffleResult(address sponsor, uint256 rid) public view returns (uint256[] memory){
        if(raffles[sponsor].length > rid){
            if(raffles[sponsor][rid].rType == RaffleType.Random){
                uint256[] memory randoms = RandomNumbers.generateNumbers(
                    raffles[sponsor][rid].seed,
                    raffles[sponsor][rid].sum,
                    raffles[sponsor][rid].min,
                    raffles[sponsor][rid].winners
                );
                return randoms;
            }else if(raffles[sponsor][rid].rType == RaffleType.Normal){
                uint256[] memory randoms = new uint256[](raffles[sponsor][rid].winners);
                for (uint256 i = 0; i < raffles[sponsor][rid].winners; i++) {
                    randoms[i] = raffles[sponsor][rid].sum.div(raffles[sponsor][rid].winners);
                }
                return randoms;
            }else{
                return new uint256[](0);
            }

        }else{
            return new uint256[](0);
        }
    }
    /**
    *获取指定人所有的抽奖的中奖号码
    */
    function getRaffleResults(address sponsor) public view returns (uint256[][] memory){
        if(raffles[sponsor].length > 0){
            uint256 [][] memory randoms = new uint256[][](raffles[sponsor].length);
            for(uint256 i = 0 ; i < raffles[sponsor].length; i++){
                uint256[] memory random = getRaffleResult(sponsor, i);
                randoms[i] = random;
            }

            return randoms;
        }else{
            return new uint256[][](0);
        }
    }
    /**
    *获取指定人所有的抽奖信息
    */
    function getRaffles(address sponsor) public view returns (Raffle[] memory){
        if(raffles[sponsor].length > 0){
            return raffles[sponsor];
        }else{
            return new Raffle[](0);
        }
    }
    /**
    *指定用户指定抽奖id开奖，中奖名单users
    */
    function draw(address sponsor, uint256 rid, address[] calldata users) public onlyOwner{
        require(sponsor != address (0), "Invalid sponsor address");
        require(raffles[sponsor].length > rid, "No such raffle");
        require(raffles[sponsor][rid].owner != address (0), "Raffle owner invalid");
        require(raffles[sponsor][rid].deadline1 >= block.timestamp, "Draw date overdue");
        require(users.length > 0, "users can't be empty");
        require(raffles[sponsor][rid].pickedIndex < raffles[sponsor][rid].winners, "Draw amount exceeded");

        Raffle memory raffle = raffles[sponsor][rid];
        uint256[] memory randoms = getRaffleResult(sponsor, rid);
        uint256 start = raffle.pickedIndex;
        uint256 max = start + users.length > raffle.winners ? raffle.winners : start + users.length;
        for(uint256 i = start; i < max; i++){
            if(address(users[i - start]).isContract()){
                continue;
            }
            IERC20Upgradeable(raffle.bonus).safeTransfer(address(users[i - start]), randoms[i]);
            raffles[sponsor][rid].picked = raffles[sponsor][rid].picked + randoms[i];
            raffles[sponsor][rid].pickedIndex = raffles[sponsor][rid].pickedIndex + 1;
            availableDecrease(raffle.bonus, randoms[i]);//减少available
            emit Draw(sponsor, rid, address(users[i - start]), randoms[i]);
        }
    }
    /**
    *给单个参与者开奖
    **/
    function drawSingle(address sponsor, uint256 rid, address user) public onlyOwner{
        require(sponsor != address (0), "Invalid sponsor address");
        require(raffles[sponsor].length > rid, "No such raffle");
        require(raffles[sponsor][rid].owner != address (0), "Raffle owner invalid");
        require(raffles[sponsor][rid].deadline1 >= block.timestamp, "Draw date overdue");
        require(user != address (0), "users can't be empty");
        require(raffles[sponsor][rid].pickedIndex < raffles[sponsor][rid].winners, "Draw amount exceeded");
        Raffle memory raffle = raffles[sponsor][rid];
        uint256[] memory randoms = getRaffleResult(sponsor, rid);

        IERC20Upgradeable(raffle.bonus).safeTransfer(address(user), randoms[raffle.pickedIndex]);
        emit Draw(sponsor, rid, address(user), randoms[raffle.pickedIndex]);
        raffles[sponsor][rid].picked = raffles[sponsor][rid].picked + randoms[raffle.pickedIndex];
        raffles[sponsor][rid].pickedIndex = raffles[sponsor][rid].pickedIndex + 1;
        availableDecrease(raffle.bonus, randoms[raffle.pickedIndex]);//减少available

    }
    /**
    清理指定的抽奖信息
     */
    function cleanRaffles(address sponsor, uint256 rid) public {
        require(raffles[sponsor].length > 0, "!sponsor");
        require(raffles[sponsor][rid].owner != address(0), "!rid");
        if(raffles[sponsor][rid].deadline2 < block.timestamp){
            if(raffles[sponsor][rid].sum > raffles[sponsor][rid].picked){
                lockIncrease(raffles[sponsor][rid].bonus, raffles[sponsor][rid].sum - raffles[sponsor][rid].picked);//冻结当前bonus的余额
            }
            //不清理
//            if(raffles[sponsor].length > 1){
//                raffles[sponsor][rid] = raffles[sponsor][raffles[sponsor].length - 1];
//            }
//            raffles[sponsor].pop();
            raffles[sponsor][rid].rState = RaffleState.Frozen;//冻结了
            emit CleanRaffle(msg.sender, sponsor, rid, raffles[sponsor][rid].sum - raffles[sponsor][rid].picked);
        }
    }
    //可用资金增加（用户新增抽奖）
    function availableIncrease(address _token, uint256 _amount) internal {
        assetAvailable[_token] = assetAvailable[_token] + _amount;
    }
    //可用资金减少（用户开奖或超过提现日期）
    function availableDecrease(address _token, uint256 _amount) internal {
        require(assetAvailable[_token] >= _amount, "Bad decrease amount");
        if(assetAvailable[_token] < _amount){
            _amount = assetAvailable[_token];
        }
        assetAvailable[_token] = assetAvailable[_token] - _amount;
    }
    //锁定资金增加
    function lockIncrease(address _token, uint256 _amount) internal {
        availableDecrease(_token, _amount);
        assetLocked[_token] = assetLocked[_token] + _amount;
    }
    //锁定资金减少（治理账户提现）
    function lockDecrease(address _token, uint256 _amount) internal {
        //availableDecrease(_token, _amount);
        require(assetLocked[_token] >= _amount, "Bad unlock amount");
        assetLocked[_token] = assetLocked[_token] - _amount;
    }
    function govClaim(address _token) public onlyGov {
        require(address(_token) != address(0) && assetLocked[_token] > 0, "Insufficient balance");
        IERC20Upgradeable(_token).safeTransfer(govAddress, assetLocked[_token]);
        assetLocked[_token] = 0;
    }
//    function govClaimExact(address _token, uint256 _amount) public onlyGov {
//        require(address(_token) != address(0) && assetLocked[_token] >= _amount, "Insufficient balance");
//        IERC20Upgradeable(_token).safeTransfer(govAddress, _amount);
//        assetLocked[_token] = 0;
//    }
//    function govClaimETH(uint256 _amount) public onlyGov {
//        payable(govAddress).sendValue(_amount);
//    }
//    function govClaimAll(address _token) public onlyGov {
//        IERC20Upgradeable(_token).safeTransfer(govAddress, IERC20Upgradeable(_token).balanceOf(address (this)));
//        assetLocked[_token] = 0;
//    }
    //治理账户赎回冻结资金
    function govMultiClaim(address[] calldata _tokens) public onlyGov {
        for(uint256 i = 0; i < _tokens.length; i++){
            address token = _tokens[i];
            if(assetLocked[token] > 0){
                govClaim(token);
            }
        }
    }
    //发起者赎回剩余资金
    function userClaim(uint256 rid) public {
        require(raffles[msg.sender].length > 0, "Invalid user");
        require(raffles[msg.sender][rid].owner == msg.sender, "Invalid rid");
        require(raffles[msg.sender][rid].rState == RaffleState.Active, "!Active");
        require(raffles[msg.sender][rid].deadline2 >= block.timestamp, "Claim expired");
        require(raffles[msg.sender][rid].deadline1 <= block.timestamp, "Claim disabled");
        uint256 claimable = raffles[msg.sender][rid].sum - raffles[msg.sender][rid].picked;
        require(claimable > 0, 'Nothing claimable');
        require(assetAvailable[raffles[msg.sender][rid].bonus] >= claimable, 'Insufficient bonus');
        IERC20Upgradeable(raffles[msg.sender][rid].bonus).safeTransfer(msg.sender, claimable);
        availableDecrease(raffles[msg.sender][rid].bonus, claimable);
        raffles[msg.sender][rid].picked = raffles[msg.sender][rid].sum;
        raffles[msg.sender][rid].rState = RaffleState.Claimed;//设置为已申索
        emit UserClaim(msg.sender, raffles[msg.sender][rid].bonus, claimable);
    }
    //设置手续费开关
    function setFee(uint256 _fee) public onlyGov {
        require(_fee <= raffleConfig.feeCap, "!cap");
        raffleConfig.feePerWinner = _fee;
        emit SetFee(_fee);
    }
    //设置手续费开关
    function setMaxWithdrawDelay(uint64 _delay) public onlyGov {
        require(_delay <= 7 days, "!cap");
        raffleConfig.maxWithdrawDelay = _delay;
        emit SetMaxWithdrawDelay(_delay);
    }
    //设置最终提现日延迟天数
    function setMaxDrawDelay(uint64 _delay) public onlyGov {
        require(_delay <= 7 days, "!cap");
        raffleConfig.maxDrawDelay = _delay;
        emit SetMaxDrawDelay(_delay);
    }
}