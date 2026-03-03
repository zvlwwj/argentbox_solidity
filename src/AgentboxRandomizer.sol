// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";

interface IAgentboxCore {
    function processRespawn(uint256 roleId, uint256 randomWord) external;
    function processNPCRefresh(uint256 npcId, uint256 randomWord) external;
    function processSpawn(uint256 roleId, uint256 randomWord) external;
}

contract AgentboxRandomizer is Ownable, VRFConsumerBaseV2 {
    VRFCoordinatorV2Interface public COORDINATOR;
    uint64 public s_subscriptionId;
    bytes32 public s_keyHash;
    uint32 public callbackGasLimit = 500000;
    uint16 public requestConfirmations = 3;

    address public gameCore;

    enum RequestType {
        Respawn,
        NPCRefresh,
        Spawn
    }

    struct RequestInfo {
        RequestType reqType;
        uint256 targetId;
    }

    mapping(uint256 => RequestInfo) public requests;

    constructor(address vrfCoordinator, bytes32 keyHash, uint64 subscriptionId)
        Ownable(msg.sender)
        VRFConsumerBaseV2(vrfCoordinator)
    {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        s_keyHash = keyHash;
        s_subscriptionId = subscriptionId;
    }

    function setGameCore(address _core) external onlyOwner {
        gameCore = _core;
    }

    modifier onlyCore() {
        require(msg.sender == gameCore, "Only game core");
        _;
    }

    function requestRespawn(uint256 roleId) external onlyCore returns (uint256 requestId) {
        requestId =
            COORDINATOR.requestRandomWords(s_keyHash, s_subscriptionId, requestConfirmations, callbackGasLimit, 1);
        requests[requestId] = RequestInfo({reqType: RequestType.Respawn, targetId: roleId});
    }

    function requestSpawn(uint256 roleId) external onlyCore returns (uint256 requestId) {
        requestId =
            COORDINATOR.requestRandomWords(s_keyHash, s_subscriptionId, requestConfirmations, callbackGasLimit, 1);
        requests[requestId] = RequestInfo({reqType: RequestType.Spawn, targetId: roleId});
    }

    function requestNPCRefresh(uint256 npcId) external onlyCore returns (uint256 requestId) {
        requestId =
            COORDINATOR.requestRandomWords(s_keyHash, s_subscriptionId, requestConfirmations, callbackGasLimit, 1);
        requests[requestId] = RequestInfo({reqType: RequestType.NPCRefresh, targetId: npcId});
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        RequestInfo memory req = requests[requestId];
        if (req.reqType == RequestType.Respawn) {
            IAgentboxCore(gameCore).processRespawn(req.targetId, randomWords[0]);
        } else if (req.reqType == RequestType.NPCRefresh) {
            IAgentboxCore(gameCore).processNPCRefresh(req.targetId, randomWords[0]);
        } else if (req.reqType == RequestType.Spawn) {
            IAgentboxCore(gameCore).processSpawn(req.targetId, randomWords[0]);
        }
    }
}
