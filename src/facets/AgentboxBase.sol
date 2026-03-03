// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../storage/AgentboxStorage.sol";
import "../AgentboxRole.sol";
import "../AgentboxRoleWallet.sol";

abstract contract AgentboxBase {
    event CharacterRegistered(uint256 indexed roleId, address indexed roleWallet);
    event LandBought(uint256 indexed landId, address indexed owner);
    event LandSold(uint256 indexed landId, address indexed owner);
    event LandContractSet(uint256 indexed landId, address indexed contractAddress);
    event MessageSent(address indexed fromWallet, address indexed toWallet, string message);
    event GlobalMessageSent(address indexed fromWallet, string message);

    modifier onlyRoleController(address roleWallet) {
        AgentboxRole roleToken = AgentboxRole(AgentboxStorage.getStorage().roleContract);
        uint256 roleId = AgentboxRoleWallet(payable(roleWallet)).roleId();
        require(roleToken.wallets(roleId) == roleWallet, "Invalid role wallet");

        address controller = roleToken.controllerOf(roleId);
        if (controller != address(0)) {
            require(controller == msg.sender, "Not controller");
        } else {
            require(roleToken.ownerOf(roleId) == msg.sender, "Not owner");
        }
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == AgentboxStorage.getStorage().owner, "Not owner");
        _;
    }

    modifier onlyRandomizer() {
        require(msg.sender == AgentboxStorage.getStorage().randomizerContract, "Only randomizer");
        _;
    }
}