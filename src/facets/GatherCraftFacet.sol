// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AgentboxBase.sol";
import "../AgentboxConfig.sol";
import "../AgentboxResource.sol";

contract GatherCraftFacet is AgentboxBase {
    function gather(address roleWallet) external onlyRoleController(roleWallet) {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        AgentboxStorage.RoleData storage role = state.roles[roleWallet];
        require(role.state == AgentboxStorage.RoleState.Idle, "Role not idle");

        AgentboxConfig config = AgentboxConfig(state.configContract);
        uint256 landId = role.position.y * config.mapWidth() + role.position.x;
        AgentboxStorage.ResourcePoint storage rp = state.resourcePoints[landId];

        require(rp.isResourcePoint, "Not a resource point");
        require(rp.stock > 0, "Resource depleted");
        require(role.skills[rp.resourceType], "Missing required skill");

        uint256 gatherAmount = 1;

        if (rp.stock < gatherAmount) {
            gatherAmount = rp.stock;
        }

        rp.stock -= gatherAmount;
        
        if (state.resourceContract != address(0)) {
            AgentboxResource(state.resourceContract).mint(roleWallet, rp.resourceType, gatherAmount, "");
        }

        if (rp.stock == 0) {
            rp.isResourcePoint = false;
        }
    }

    function startGather(address roleWallet, uint256 amount) external onlyRoleController(roleWallet) {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        AgentboxStorage.RoleData storage role = state.roles[roleWallet];
        require(role.state == AgentboxStorage.RoleState.Idle, "Role not idle");

        AgentboxConfig config = AgentboxConfig(state.configContract);
        uint256 landId = role.position.y * config.mapWidth() + role.position.x;
        AgentboxStorage.ResourcePoint storage rp = state.resourcePoints[landId];

        require(rp.isResourcePoint, "Not a resource point");
        require(rp.stock >= amount, "Not enough resource stock");
        require(role.skills[rp.resourceType], "Missing required skill");

        uint256 blocksPerResource = 2; // Fixed blocks per resource
        uint256 requiredBlocks = amount * blocksPerResource;

        rp.stock -= amount;
        if (rp.stock == 0) {
            rp.isResourcePoint = false;
        }

        role.state = AgentboxStorage.RoleState.Gathering;
        role.gathering = AgentboxStorage.GatheringState({
            startBlock: block.number,
            requiredBlocks: requiredBlocks,
            targetLandId: landId,
            amount: amount
        });
    }

    function finishGather(address roleWallet) external onlyRoleController(roleWallet) {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        AgentboxStorage.RoleData storage role = state.roles[roleWallet];

        require(role.state == AgentboxStorage.RoleState.Gathering, "Role not gathering");
        require(block.number >= role.gathering.startBlock + role.gathering.requiredBlocks, "Gathering not finished yet");

        uint256 targetLandId = role.gathering.targetLandId;
        AgentboxStorage.ResourcePoint storage rp = state.resourcePoints[targetLandId];

        role.state = AgentboxStorage.RoleState.Idle;

        if (state.resourceContract != address(0)) {
            AgentboxResource(state.resourceContract).mint(roleWallet, rp.resourceType, role.gathering.amount, "");
        }
    }

    function startCrafting(address roleWallet, uint256 recipeId) external onlyRoleController(roleWallet) {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        AgentboxStorage.RoleData storage role = state.roles[roleWallet];
        require(role.state == AgentboxStorage.RoleState.Idle, "Role not idle");

        AgentboxStorage.Recipe storage recipe = state.recipes[recipeId];
        require(recipe.outputEquipmentId != 0, "Invalid recipe");
        require(role.skills[recipe.requiredSkill], "Missing required skill");
        
        // Verify balances and deduct resources
        for (uint256 i = 0; i < recipe.requiredResources.length; i++) {
            uint256 resId = recipe.requiredResources[i];
            uint256 amt = recipe.requiredAmounts[i];
            require(AgentboxResource(state.resourceContract).balanceOf(roleWallet, resId) >= amt, "Not enough resources");
            AgentboxResource(state.resourceContract).burn(roleWallet, resId, amt);
        }

        // Set state
        role.state = AgentboxStorage.RoleState.Crafting;
        role.crafting = AgentboxStorage.CraftingState({
            startBlock: block.number,
            requiredBlocks: recipe.requiredBlocks,
            recipeId: recipeId
        });
    }

    function finishCrafting(address roleWallet) external onlyRoleController(roleWallet) {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        AgentboxStorage.RoleData storage role = state.roles[roleWallet];
        require(role.state == AgentboxStorage.RoleState.Crafting, "Not crafting");
        require(block.number >= role.crafting.startBlock + role.crafting.requiredBlocks, "Crafting not finished");

        AgentboxStorage.Recipe storage recipe = state.recipes[role.crafting.recipeId];

        // Output equipment
        AgentboxResource(state.resourceContract).mint(roleWallet, recipe.outputEquipmentId, 1, "");
        role.state = AgentboxStorage.RoleState.Idle;
    }

    function equip(address roleWallet, uint256 equipmentId) external onlyRoleController(roleWallet) {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        AgentboxStorage.RoleData storage role = state.roles[roleWallet];
        require(role.state == AgentboxStorage.RoleState.Idle, "Role not idle");

        AgentboxStorage.EquipmentConfig storage config = state.equipments[equipmentId];
        require(config.slot > 0, "Not an equipment");

        // Verify balance
        require(AgentboxResource(state.resourceContract).balanceOf(roleWallet, equipmentId) > 0, "Do not own equipment");

        uint256 slot = config.slot;
        uint256 currentEq = role.equippedItems[slot];

        if (currentEq != 0) {
            _removeEquipmentStats(role, state.equipments[currentEq]);
            // return currentEq to inventory
            AgentboxResource(state.resourceContract).mint(roleWallet, currentEq, 1, "");
        }

        // burn the newly equipped item from inventory
        AgentboxResource(state.resourceContract).burn(roleWallet, equipmentId, 1);
        
        role.equippedItems[slot] = equipmentId;
        _applyEquipmentStats(role, config);
    }

    function unequip(address roleWallet, uint256 slot) external onlyRoleController(roleWallet) {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        AgentboxStorage.RoleData storage role = state.roles[roleWallet];
        require(role.state == AgentboxStorage.RoleState.Idle, "Role not idle");

        uint256 currentEq = role.equippedItems[slot];
        require(currentEq != 0, "Nothing equipped in slot");

        role.equippedItems[slot] = 0;
        _removeEquipmentStats(role, state.equipments[currentEq]);

        // return item to inventory
        AgentboxResource(state.resourceContract).mint(roleWallet, currentEq, 1, "");
    }

    function _applyEquipmentStats(AgentboxStorage.RoleData storage role, AgentboxStorage.EquipmentConfig memory config) internal {
        role.attributes.speed = _addIntToUint(role.attributes.speed, config.speedBonus);
        role.attributes.attack = _addIntToUint(role.attributes.attack, config.attackBonus);
        role.attributes.defense = _addIntToUint(role.attributes.defense, config.defenseBonus);
        role.attributes.maxHp = _addIntToUint(role.attributes.maxHp, config.maxHpBonus);
        role.attributes.range = _addIntToUint(role.attributes.range, config.rangeBonus);
    }

    function _removeEquipmentStats(AgentboxStorage.RoleData storage role, AgentboxStorage.EquipmentConfig memory config) internal {
        role.attributes.speed = _addIntToUint(role.attributes.speed, -config.speedBonus);
        role.attributes.attack = _addIntToUint(role.attributes.attack, -config.attackBonus);
        role.attributes.defense = _addIntToUint(role.attributes.defense, -config.defenseBonus);
        role.attributes.maxHp = _addIntToUint(role.attributes.maxHp, -config.maxHpBonus);
        role.attributes.range = _addIntToUint(role.attributes.range, -config.rangeBonus);

        if (role.attributes.hp > role.attributes.maxHp) {
            role.attributes.hp = role.attributes.maxHp;
        }
    }

    function _addIntToUint(uint256 a, int256 b) internal pure returns (uint256) {
        if (b < 0) {
            uint256 absB = uint256(-b);
            return a > absB ? a - absB : 0;
        } else {
            return a + uint256(b);
        }
    }
}