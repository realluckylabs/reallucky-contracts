// SPDX-License-Identifier: MIT
// An example of a consumer contract that relies on a subscription for funding.
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/**
 * THIS IS AN EXAMPLE CONTRACT THAT USES HARDCODED VALUES FOR CLARITY.
 * THIS IS AN EXAMPLE CONTRACT THAT USES UN-AUDITED CODE.
 * DO NOT USE THIS CODE IN PRODUCTION.
 */

/**
 * @title The RandomNumberConsumerV2 contract
 * @notice A contract that gets random values from Chainlink VRF V2
 */
contract RandomNumberConsumerV2 is VRFConsumerBaseV2 {
    VRFCoordinatorV2Interface immutable COORDINATOR;

    // Your subscription ID.
    uint64 immutable s_subscriptionId;

    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/docs/vrf-contracts/#configurations
    bytes32 immutable s_keyHash;

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
    // so 100,000 is a safe default for this example contract. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    uint32 constant CALLBACK_GAS_LIMIT = 100000;

    // The default is 3, but you can set this higher.
    uint16 constant REQUEST_CONFIRMATIONS = 3;

    // For this example, retrieve 2 random values in one request.
    // Cannot exceed VRFCoordinatorV2.MAX_NUM_WORDS.
    uint32 constant NUM_WORDS = 10;

    uint256[] public s_randomWords;
    uint256 public s_requestId;
    address s_owner;

    //Custom
    struct Raffle{
        address name;
        uint256 seed;
    }
    mapping(address => Raffle[]) public users;
    address[] public userList;
    struct Caller{
        address addr;
        uint256 index;
    }
    mapping(uint256 => Caller) public callers;

    event ReturnedRandomness(uint256 requestId, uint256[] randomWords);
    event RequestRandom(uint256 requestId, address who);

    /**
     * @notice Constructor inherits VRFConsumerBaseV2
     *
     * @param subscriptionId - the subscription ID that this contract uses for funding requests
     * @param vrfCoordinator - coordinator, check https://docs.chain.link/docs/vrf-contracts/#configurations
     * @param keyHash - the gas lane to use, which specifies the maximum gas price to bump to
     */
    constructor(
        uint64 subscriptionId,
        address vrfCoordinator,
        bytes32 keyHash
    ) VRFConsumerBaseV2(vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        s_keyHash = keyHash;
        s_owner = msg.sender;
        s_subscriptionId = subscriptionId;
    }

    /**
     * @notice Requests randomness
     * Assumes the subscription is funded sufficiently; "Words" refers to unit of data in Computer Science
     */
    function requestRandomWords() external onlyOwner {
        // Will revert if subscription is not set and funded.
        s_requestId = COORDINATOR.requestRandomWords(
            s_keyHash,
            s_subscriptionId,
            REQUEST_CONFIRMATIONS,
            CALLBACK_GAS_LIMIT,
            NUM_WORDS
        );
        users[msg.sender].push(Raffle({
            name:msg.sender,
            seed:0
        }));
        if(users[msg.sender].length == 0){
            userList.push(msg.sender);//记录用户的信息
        }
        require(users[msg.sender].length > 0, "users can't be empty!!");

        callers[s_requestId] = Caller({
            addr:msg.sender,
            index:users[msg.sender].length - 1
        });
        emit RequestRandom(s_requestId, msg.sender);
    }


    function fulfillRandomWords(
        uint256 requestId/* requestId */,
        uint256[] memory randomWords
    ) internal override {
        s_randomWords = randomWords;
        //获取调用者信息，address和数组id
        if(callers[requestId].addr != address(0)){
            if(users[callers[requestId].addr].length > callers[requestId].index){
                users[callers[requestId].addr][callers[requestId].index].seed = randomWords[0];
            }
            delete callers[requestId];//删除caller槽内的数据，节省gas
        }
        emit ReturnedRandomness(requestId, randomWords);
    }

    modifier onlyOwner() {
        require(msg.sender == s_owner);
        _;
    }
}
