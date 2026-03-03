// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/AgentboxConfig.sol";
import "../src/AgentboxRoleWallet.sol";
import "../src/AgentboxRole.sol";
import "../src/AgentboxRandomizer.sol";
import "../src/AgentboxEconomy.sol";
import "../src/AgentboxResource.sol";
import "../src/AgentboxCore.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2Mock.sol";

contract AgentboxCoreTest is Test {
    AgentboxConfig config;
    AgentboxRoleWallet walletImpl;
    AgentboxRole roleToken;
    VRFCoordinatorV2Mock vrfMock;
    AgentboxRandomizer randomizer;
    AgentboxEconomy economy;
    AgentboxResource resource;
    AgentboxCore core;

    address player1 = address(0x111);
    uint64 subId;

    function setUp() public {
        vm.deal(player1, 10 ether);

        // Deploy config
        config = new AgentboxConfig();

        // Deploy role system
        walletImpl = new AgentboxRoleWallet();
        roleToken = new AgentboxRole(address(walletImpl));

        // Deploy VRF Mock
        vrfMock = new VRFCoordinatorV2Mock(0.1 ether, 1e9);
        subId = vrfMock.createSubscription();
        vrfMock.fundSubscription(subId, 100 ether);

        // Deploy Randomizer
        randomizer = new AgentboxRandomizer(address(vrfMock), bytes32(0), subId);
        vrfMock.addConsumer(subId, address(randomizer));

        // Deploy Economy
        economy = new AgentboxEconomy(address(config), address(vrfMock), bytes32(0), subId);
        vrfMock.addConsumer(subId, address(economy));

        // Deploy Resource
        resource = new AgentboxResource();

        // Deploy Core with Proxy
        AgentboxCore coreImpl = new AgentboxCore();
        bytes memory initData = abi.encodeWithSelector(
            AgentboxCore.initialize.selector,
            address(roleToken),
            address(config),
            address(economy),
            address(randomizer),
            address(resource)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(coreImpl), initData);
        core = AgentboxCore(address(proxy));

        // Set references
        randomizer.setGameCore(address(core));
        economy.setGameCore(address(core));
        resource.setGameCore(address(core));
    }

    function test_RegisterCharacter() public {
        vm.startPrank(player1);

        uint256 roleId = roleToken.mint();
        address walletAddr = roleToken.wallets(roleId);
        assertTrue(walletAddr != address(0), "Wallet not created");

        // Register
        core.registerCharacter{value: 0.01 ether}(roleId);

        // Check state
        (bool isValid, uint256 x, uint256 y) = core.getEntityPosition(walletAddr);
        // Initially should be (0,0) and state PendingSpawn (since VRF not fulfilled yet)
        assertFalse(isValid, "Should not be fully valid until VRF resolves"); 

        vm.stopPrank();

        // Fulfill VRF for spawn
        // We need to find the requestId. Randomizer should have requestId 1 if it's the first request
        vrfMock.fulfillRandomWords(1, address(randomizer));

        (isValid, x, y) = core.getEntityPosition(walletAddr);
        assertTrue(isValid, "Character should be valid after spawn");
    }

    function test_Movement() public {
        vm.startPrank(player1);
        uint256 roleId = roleToken.mint();
        address walletAddr = roleToken.wallets(roleId);
        core.registerCharacter{value: 0.01 ether}(roleId);
        vm.stopPrank();

        vrfMock.fulfillRandomWords(1, address(randomizer));

        // Start movement
        vm.startPrank(player1);
        core.startMove(walletAddr, 100, 100);
        vm.stopPrank();

        // Mine blocks to pass movement time
        vm.roll(block.number + 100000);

        vm.startPrank(player1);
        core.finishMove(walletAddr);
        vm.stopPrank();

        (bool isValid, uint256 x, uint256 y) = core.getEntityPosition(walletAddr);
        assertTrue(isValid, "Should be valid");
        assertEq(x, 100, "X should be 100");
        assertEq(y, 100, "Y should be 100");
    }
}
