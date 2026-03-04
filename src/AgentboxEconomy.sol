// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {IVRFCoordinatorV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import "./AgentboxConfig.sol";

contract AgentboxEconomy is ERC20, VRFConsumerBaseV2Plus {
    AgentboxConfig public config;
    IVRFCoordinatorV2Plus public COORDINATOR;

    uint256 public s_subscriptionId;
    bytes32 public s_keyHash;
    uint32 public callbackGasLimit = 500000;
    uint16 public requestConfirmations = 3;

    struct UnreliableBalance {
        uint256 amount;
        uint256 obtainedBlock;
    }

    mapping(uint256 => uint256) public groundTokens;
    mapping(address => UnreliableBalance[]) private _unreliableBalances;

    uint256 public lastMintBlock;
    uint256 public mintsCount;

    address public gameCore;
    mapping(uint256 => bool) public pendingMintRequests;

    bool private _isBypassingReliableCheck;

    event TokensDropped(uint256 indexed landId, uint256 amount);
    event TokensPickedUp(address indexed account, uint256 indexed landId, uint256 amount);
    event TokensStabilized(address indexed account, uint256 amount);

    constructor(address _config, address vrfCoordinator, bytes32 keyHash, uint256 subscriptionId)
        ERC20("AgentboxCoin", "AGC")
        VRFConsumerBaseV2Plus(vrfCoordinator)
    {
        config = AgentboxConfig(_config);
        s_keyHash = keyHash;
        s_subscriptionId = subscriptionId;
        lastMintBlock = block.number;
    }

    function setGameCore(address _core) external onlyOwner {
        gameCore = _core;
    }

    modifier onlyCore() {
        require(msg.sender == gameCore, "Only game core");
        _;
    }

    function triggerMint() external {
        require(block.number >= lastMintBlock + config.mintIntervalBlocks(), "Too early");
        lastMintBlock = block.number;

        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: s_keyHash,
                subId: s_subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: 1,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
            })
        );
        pendingMintRequests[requestId] = true;
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        if (pendingMintRequests[requestId]) {
            delete pendingMintRequests[requestId];

            if (mintsCount >= 160000) {
                return; // Max supply reached (160,000 mints * 1000 tokens = 160,000,000 tokens)
            }

            uint256 mapWidth = config.mapWidth();
            uint256 mapHeight = config.mapHeight();

            uint256 landId = randomWords[0] % (mapWidth * mapHeight);

            uint256 currentMintAmount = 1000 * 10**decimals();

            groundTokens[landId] += currentMintAmount;
            mintsCount++;

            emit TokensDropped(landId, currentMintAmount);
        }
    }

    function pickupTokens(address account, uint256 x, uint256 y) external onlyCore {
        uint256 landId = y * config.mapWidth() + x;
        uint256 amount = groundTokens[landId];
        if (amount > 0) {
            groundTokens[landId] = 0;
            _unreliableBalances[account].push(UnreliableBalance({amount: amount, obtainedBlock: block.number}));
            _isBypassingReliableCheck = true;
            _mint(account, amount);
            _isBypassingReliableCheck = false;
            emit TokensPickedUp(account, landId, amount);
        }
    }

    function stabilizeBalance(address account) public {
        uint256 stabilizationBlocks = config.stabilizationBlocks();
        UnreliableBalance[] storage balances = _unreliableBalances[account];

        uint256 stableAmount = 0;
        uint256 i = 0;
        while (i < balances.length) {
            if (block.number >= balances[i].obtainedBlock + stabilizationBlocks) {
                stableAmount += balances[i].amount;
                balances[i] = balances[balances.length - 1];
                balances.pop();
            } else {
                i++;
            }
        }

        if (stableAmount > 0) {
            emit TokensStabilized(account, stableAmount);
        }
    }

    function unreliableBalanceOf(address account) public view returns (uint256 total) {
        UnreliableBalance[] memory balances = _unreliableBalances[account];
        for (uint256 i = 0; i < balances.length; i++) {
            total += balances[i].amount;
        }
    }

    function transferUnreliableOnDeath(address fromAccount, address toAccount) external onlyCore {
        uint256 total = unreliableBalanceOf(fromAccount);
        delete _unreliableBalances[fromAccount];
        if (total > 0) {
            _unreliableBalances[toAccount].push(UnreliableBalance({amount: total, obtainedBlock: block.number}));
            _isBypassingReliableCheck = true;
            _transfer(fromAccount, toAccount, total);
            _isBypassingReliableCheck = false;
        }
    }

    function burnReliable(address account, uint256 amount) external onlyCore {
        stabilizeBalance(account);
        uint256 totalUnreliable = unreliableBalanceOf(account);
        uint256 currentBalance = balanceOf(account);
        uint256 reliable = currentBalance > totalUnreliable ? currentBalance - totalUnreliable : 0;
        require(amount <= reliable, "Insufficient reliable balance");
        
        _isBypassingReliableCheck = true;
        _burn(account, amount);
        _isBypassingReliableCheck = false;
    }

    function _update(address from, address to, uint256 value) internal override {
        if (from != address(0) && !_isBypassingReliableCheck) {
            stabilizeBalance(from);
            uint256 totalUnreliable = unreliableBalanceOf(from);
            uint256 currentBalance = balanceOf(from);
            uint256 reliable = currentBalance > totalUnreliable ? currentBalance - totalUnreliable : 0;
            require(value <= reliable, "Insufficient reliable balance");
        }
        super._update(from, to, value);
    }
}
