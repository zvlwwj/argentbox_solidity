// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {IVRFCoordinatorV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import "./interfaces/IAgentboxCore.sol";

contract AgentboxRandomizer is VRFConsumerBaseV2Plus {
    IVRFCoordinatorV2Plus public COORDINATOR;
    uint256 public s_subscriptionId;
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

    constructor(address vrfCoordinator, bytes32 keyHash, uint256 subscriptionId)
        VRFConsumerBaseV2Plus(vrfCoordinator)
    {
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
        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: s_keyHash,
                subId: s_subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: 1,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
            })
        );
        requests[requestId] = RequestInfo({reqType: RequestType.Respawn, targetId: roleId});
    }

    function requestSpawn(uint256 roleId) external onlyCore returns (uint256 requestId) {
        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: s_keyHash,
                subId: s_subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: 1,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
            })
        );
        requests[requestId] = RequestInfo({reqType: RequestType.Spawn, targetId: roleId});
    }

    function requestNPCRefresh(uint256 npcId) external onlyCore returns (uint256 requestId) {
        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: s_keyHash,
                subId: s_subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: 1,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
            })
        );
        requests[requestId] = RequestInfo({reqType: RequestType.NPCRefresh, targetId: npcId});
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
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
