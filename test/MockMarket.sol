// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../src/interfaces/IAgentboxCore.sol";
import "../src/AgentboxEconomy.sol";
import "../src/AgentboxResource.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

contract MockMarket is ERC1155Holder {
    IAgentboxCore public core;
    AgentboxEconomy public economy;
    AgentboxResource public resource;

    struct Order {
        address sellerWallet;
        uint256 resourceType;
        uint256 amount;
        uint256 price;
        bool isActive;
    }

    mapping(uint256 => Order) public orders;
    uint256 public nextOrderId;

    constructor(address _core, address _economy, address _resource) {
        core = IAgentboxCore(_core);
        economy = AgentboxEconomy(_economy);
        resource = AgentboxResource(_resource);
    }

    // sellerWallet calls this, so msg.sender is sellerWallet
    function listOrder(uint256 resourceType, uint256 amount, uint256 price) external {
        // Resource is transferred from sellerWallet to Market
        resource.safeTransferFrom(msg.sender, address(this), resourceType, amount, "");

        orders[nextOrderId++] = Order({
            sellerWallet: msg.sender,
            resourceType: resourceType,
            amount: amount,
            price: price,
            isActive: true
        });
    }

    // buyerWallet calls this
    function buyOrder(uint256 orderId) external {
        Order storage ord = orders[orderId];
        require(ord.isActive, "Order not active");
        ord.isActive = false;

        // 1. Transfer Money (Buyer -> Seller)
        // Note: buyer must have approved Market in Economy contract!
        economy.transferFrom(msg.sender, ord.sellerWallet, ord.price);

        // 2. Transfer Resource (Market -> Buyer)
        resource.safeTransferFrom(address(this), msg.sender, ord.resourceType, ord.amount, "");
    }
}
