// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AgentboxBase.sol";
import "../AgentboxConfig.sol";

contract LearnFacet is AgentboxBase {
    function startLearning(address roleWallet, uint256 npcId) external onlyRoleController(roleWallet) {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        AgentboxStorage.RoleData storage role = state.roles[roleWallet];
        require(role.state == AgentboxStorage.RoleState.Idle, "Role not idle");

        AgentboxStorage.NPC storage npc = state.npcs[npcId];
        require(!npc.isTeaching, "NPC is busy");
        require(npc.position.x == role.position.x && npc.position.y == role.position.y, "Not at NPC");
        
        uint256 reqBlocks = state.skillRequiredBlocks[npc.npcType];
        require(reqBlocks > 0, "Skill not configured");

        role.state = AgentboxStorage.RoleState.Learning;
        role.learning = AgentboxStorage.LearningState({
            startBlock: block.number,
            requiredBlocks: reqBlocks,
            targetId: npcId,
            skillId: npc.npcType,
            isNPC: true,
            teacherWallet: address(0)
        });

        npc.isTeaching = true;
        
        // Let's store studentId as uint256 representation of wallet, or just cast it
        npc.studentId = uint160(roleWallet);
        npc.startBlock = block.number;
    }

    function startLearningFromPlayer(address roleWallet, address teacherWallet, uint256 skillId) external onlyRoleController(roleWallet) {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        AgentboxStorage.RoleData storage role = state.roles[roleWallet];
        AgentboxStorage.RoleData storage teacher = state.roles[teacherWallet];

        require(role.state == AgentboxStorage.RoleState.Idle, "Student not idle");
        require(teacher.state == AgentboxStorage.RoleState.Idle, "Teacher not idle");
        require(role.position.x == teacher.position.x && role.position.y == teacher.position.y, "Not at teacher");
        require(teacher.skills[skillId], "Teacher does not have skill");
        require(!role.skills[skillId], "Student already has skill");

        uint256 baseReqBlocks = state.skillRequiredBlocks[skillId];
        require(baseReqBlocks > 0, "Skill not configured");

        uint256 reqBlocks = baseReqBlocks * 2;

        // Set student state
        role.state = AgentboxStorage.RoleState.Learning;
        role.learning = AgentboxStorage.LearningState({
            startBlock: block.number,
            requiredBlocks: reqBlocks,
            targetId: 0,
            skillId: skillId,
            isNPC: false,
            teacherWallet: teacherWallet
        });

        // Set teacher state
        teacher.state = AgentboxStorage.RoleState.Teaching;
        teacher.teaching = AgentboxStorage.TeachingState({
            startBlock: block.number,
            requiredBlocks: reqBlocks,
            studentWallet: roleWallet,
            skillId: skillId
        });
    }

    function finishLearning(address roleWallet) external onlyRoleController(roleWallet) {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        AgentboxStorage.RoleData storage role = state.roles[roleWallet];
        require(role.state == AgentboxStorage.RoleState.Learning, "Not learning");
        require(block.number >= role.learning.startBlock + role.learning.requiredBlocks, "Learning not finished");

        role.state = AgentboxStorage.RoleState.Idle;
        role.skills[role.learning.skillId] = true;

        if (role.learning.isNPC) {
            AgentboxStorage.NPC storage npc = state.npcs[role.learning.targetId];
            npc.isTeaching = false;

            if (state.randomizerContract != address(0)) {
                (bool success,) = state.randomizerContract.call(
                    abi.encodeWithSignature("requestNPCRefresh(uint256)", role.learning.targetId)
                );
                require(success, "Randomizer request failed");
            }
        } else {
            AgentboxStorage.RoleData storage teacher = state.roles[role.learning.teacherWallet];
            if (teacher.state == AgentboxStorage.RoleState.Teaching && teacher.teaching.studentWallet == roleWallet) {
                teacher.state = AgentboxStorage.RoleState.Idle;
            }
        }
    }

    function processNPCRefresh(uint256 npcId, uint256 randomWord) external onlyRandomizer {
        AgentboxStorage.GameState storage state = AgentboxStorage.getStorage();
        AgentboxStorage.NPC storage npc = state.npcs[npcId];
        AgentboxConfig config = AgentboxConfig(state.configContract);

        npc.position.x = uint256(keccak256(abi.encode(randomWord, 1))) % config.mapWidth();
        npc.position.y = uint256(keccak256(abi.encode(randomWord, 2))) % config.mapHeight();
    }
}