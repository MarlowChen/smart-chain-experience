// SPDX-License-Identifier: MIT
// An example of a consumer contract that relies on a subscription for funding.
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract VRFv2Consumer is VRFConsumerBaseV2 {
  VRFCoordinatorV2Interface COORDINATOR;

  // Your subscription ID.
  uint64 s_subscriptionId;

  // Rinkeby coordinator. For other networks,
  // see https://docs.chain.link/docs/vrf-contracts/#configurations
  address vrfCoordinator = 0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed;

  // The gas lane to use, which specifies the maximum gas price to bump to.
  // For a list of available gas lanes on each network,
  // see https://docs.chain.link/docs/vrf-contracts/#configurations
  bytes32 keyHash = 0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f;

  // The default is 3, but you can set this higher.
  uint16 requestConfirmations = 3;


  uint256[] public s_randomWords;
  uint256 public s_requestId;
  address s_owner;
  uint256[] public _randomNumbers;
  uint256[] private resultNumbers;
  uint256[] public levelOneCollection;
  uint256[] public levelTwoCollection;
  uint256[] public levelThreeCollection;

  uint256 totalMint = 5000;
  uint256 singleRandom = 100;
  struct MysteryBoxConfig {
    uint32 gold;
    uint32 levelOne;
    uint32 silver;
    uint32 levelTwo;
  }

  MysteryBoxConfig public mysteryBoxConfig;

  constructor(uint64 subscriptionId) VRFConsumerBaseV2(vrfCoordinator) {
    COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
    s_owner = msg.sender;
    s_subscriptionId = subscriptionId;
    mysteryBoxConfig.gold = 100;
    mysteryBoxConfig.levelOne = 400;
    mysteryBoxConfig.silver = 1000;
    mysteryBoxConfig.levelTwo = 1500;
  }

  function requestRandomWords() public onlyOwner {
      s_requestId = COORDINATOR.requestRandomWords(
        keyHash,
        s_subscriptionId,
        requestConfirmations,
        100000,
        2
      );
  }
  
  function fulfillRandomWords(
    uint256, /* requestId */
    uint256[] memory randomWords
  ) internal override {
    s_randomWords = randomWords;
  }

  function setTotalMint (uint256 _totalMint) public {
    totalMint = _totalMint;
  }

  function setMysteryBoxConfig (uint32 _gold, uint32 _levelOne, uint32 _silver, uint32 _levelTwo) public {
     mysteryBoxConfig.gold  = _gold;
    mysteryBoxConfig.levelOne = _levelOne;
    mysteryBoxConfig.silver = _silver;
    mysteryBoxConfig.levelTwo = _levelTwo;   
  }

  function make (uint256 randomValue) public{
    delete resultNumbers;  
    for(uint i = 1; i <= totalMint; i++) {
      resultNumbers.push(i);
    }
    for (uint i = 0; i < totalMint; i++) {
        uint256 randomIndex;
        uint256 resultIndex;
          if(i < mysteryBoxConfig.gold){
            randomIndex = uint256(keccak256(abi.encode(randomValue, i))) % (resultNumbers.length - mysteryBoxConfig.levelOne);
            resultIndex = mysteryBoxConfig.levelOne+ randomIndex;
            levelOneCollection.push(totalMint - resultNumbers[resultIndex]);
          }else if(i >= mysteryBoxConfig.gold && i < mysteryBoxConfig.silver ){
            randomIndex =  uint256(keccak256(abi.encode(randomValue, i))) % (resultNumbers.length - mysteryBoxConfig.levelTwo);
            resultIndex = mysteryBoxConfig.levelTwo+ randomIndex;
            levelTwoCollection.push(totalMint - resultNumbers[resultIndex]);
          }else{
            randomIndex =  uint256(keccak256(abi.encode(randomValue, i))) % resultNumbers.length;
            resultIndex = randomIndex;
            levelThreeCollection.push(totalMint - resultNumbers[resultIndex]);
          }
        resultNumbers[resultIndex] = resultNumbers[resultNumbers.length - 1];
        resultNumbers.pop();  
    }
  }

  modifier onlyOwner() {
    require(msg.sender == s_owner);
    _;
  }
}
