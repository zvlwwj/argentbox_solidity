// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AgentboxBase.sol";
import "../AgentboxConfig.sol";

contract AdminFacet is AgentboxBase {
    function initialize(
        address _roleContract,
        address _configContract,
        address _economyContract,
        address _randomizerContract,
        address _resourceContract
    ) external onlyOwner {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        state.roleContract = _roleContract;
        state.configContract = _configContract;
        state.economyContract = _economyContract;
        state.randomizerContract = _randomizerContract;
        state.resourceContract = _resourceContract;
    }

    function withdrawEth() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    function setResourcePoint(uint256 x, uint256 y, uint256 resourceType, uint256 initialStock) external onlyOwner {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        AgentboxConfig config = AgentboxConfig(state.configContract);
        uint256 landId = y * config.mapWidth() + x;
        state.resourcePoints[landId] =
            AgentboxStorage.ResourcePoint({resourceType: resourceType, stock: initialStock, isResourcePoint: true});
    }

    function setSkillBlocks(uint256 skillId, uint256 requiredBlocks) external onlyOwner {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        state.skillRequiredBlocks[skillId] = requiredBlocks;
    }

    function setNPC(uint256 npcId, uint256 x, uint256 y, uint256 npcType) external onlyOwner {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        AgentboxStorage.NPC storage npc = state.npcs[npcId];
        npc.position.x = x;
        npc.position.y = y;
        npc.npcType = npcType;
    }

    function setRecipe(
        uint256 recipeId,
        uint256[] calldata resourceTypes,
        uint256[] calldata amounts,
        uint256 skillId,
        uint256 requiredBlocks,
        uint256 outputEqId
    ) external onlyOwner {
        require(resourceTypes.length == amounts.length, "Mismatched arrays");
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        state.recipes[recipeId] = AgentboxStorage.Recipe({
            requiredResources: resourceTypes,
            requiredAmounts: amounts,
            requiredSkill: skillId,
            requiredBlocks: requiredBlocks,
            outputEquipmentId: outputEqId
        });
    }

    function setEquipmentConfig(
        uint256 equipmentId,
        uint256 slot,
        int256 speedBonus,
        int256 attackBonus,
        int256 defenseBonus,
        int256 maxHpBonus,
        int256 rangeBonus
    ) external onlyOwner {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        state.equipments[equipmentId] = AgentboxStorage.EquipmentConfig({
            slot: slot,
            speedBonus: speedBonus,
            attackBonus: attackBonus,
            defenseBonus: defenseBonus,
            maxHpBonus: maxHpBonus,
            rangeBonus: rangeBonus
        });
    }
}