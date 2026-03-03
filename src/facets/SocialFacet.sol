// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AgentboxBase.sol";

contract SocialFacet is AgentboxBase {
    function sendMessage(address roleWallet, address toWallet, string calldata message) external onlyRoleController(roleWallet) {
        emit MessageSent(roleWallet, toWallet, message);
    }

    function sendGlobalMessage(address roleWallet, string calldata message) external onlyRoleController(roleWallet) {
        emit GlobalMessageSent(roleWallet, message);
    }
}