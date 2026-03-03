// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IAgentboxCore {
    function initialize(
        address _roleContract,
        address _configContract,
        address _economyContract,
        address _randomizerContract,
        address _resourceContract
    ) external;

    function registerCharacter(uint256 roleId) external payable;
    function processSpawn(uint256 roleId, uint256 randomWord) external;
    function getEntityPosition(address entity) external view returns (bool isValid, uint256 x, uint256 y);
    
    function move(address roleWallet, int256 dx, int256 dy) external;
    function startMove(address roleWallet, uint256 targetX, uint256 targetY) external;
    function finishMove(address roleWallet) external;
    function attack(address roleWallet, address targetWallet) external;
    function processRespawn(uint256 roleId, uint256 randomWord) external;

    function withdrawEth() external;
    function setResourcePoint(uint256 x, uint256 y, uint256 resourceType, uint256 initialStock) external;
    function setSkillBlocks(uint256 skillId, uint256 requiredBlocks) external;
    function setNPC(uint256 npcId, uint256 x, uint256 y, uint256 npcType) external;
    function setRecipe(uint256 recipeId, uint256[] calldata resourceTypes, uint256[] calldata amounts, uint256 skillId, uint256 requiredBlocks, uint256 outputEqId) external;
    function setEquipmentConfig(uint256 equipmentId, uint256 slot, int256 speedBonus, int256 attackBonus, int256 defenseBonus, int256 maxHpBonus, int256 rangeBonus) external;

    function gather(address roleWallet) external;
    function startGather(address roleWallet, uint256 amount) external;
    function finishGather(address roleWallet) external;
    function startCrafting(address roleWallet, uint256 recipeId) external;
    function finishCrafting(address roleWallet) external;
    function equip(address roleWallet, uint256 equipmentId) external;
    function unequip(address roleWallet, uint256 slot) external;

    function startLearning(address roleWallet, uint256 npcId) external;
    function startLearningFromPlayer(address roleWallet, address teacherWallet, uint256 skillId) external;
    function finishLearning(address roleWallet) external;
    function processNPCRefresh(uint256 npcId, uint256 randomWord) external;

    function buyLand(address roleWallet, uint256 x, uint256 y) external;
    function sellLand(address roleWallet, uint256 x, uint256 y) external;
    function setLandContract(uint256 x, uint256 y, address contractAddress) external;

    function sendMessage(address roleWallet, address toWallet, string calldata message) external;
    function sendGlobalMessage(address roleWallet, string calldata message) external;
}