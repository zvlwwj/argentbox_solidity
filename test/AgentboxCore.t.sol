// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/AgentboxConfig.sol";
import "../src/AgentboxRoleWallet.sol";
import "../src/AgentboxRole.sol";
import "../src/AgentboxRandomizer.sol";
import "../src/AgentboxEconomy.sol";
import "../src/AgentboxResource.sol";
import "../src/proxy/AgentboxDiamond.sol";
import "../src/facets/AdminFacet.sol";
import "../src/facets/ActionFacet.sol";
import "../src/facets/GatherCraftFacet.sol";
import "../src/facets/LearnFacet.sol";
import "../src/facets/MapFacet.sol";
import "../src/facets/RoleFacet.sol";
import "../src/facets/SocialFacet.sol";
import "../src/interfaces/IAgentboxCore.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2Mock.sol";

contract AgentboxCoreTest is Test {
    AgentboxConfig config;
    AgentboxRoleWallet walletImpl;
    AgentboxRole roleToken;
    VRFCoordinatorV2Mock vrfMock;
    AgentboxRandomizer randomizer;
    AgentboxEconomy economy;
    AgentboxResource resource;
    IAgentboxCore core;

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

        // Deploy Diamond
        AgentboxDiamond diamond = new AgentboxDiamond();
        
        // Deploy Facets
        AdminFacet adminFacet = new AdminFacet();
        ActionFacet actionFacet = new ActionFacet();
        GatherCraftFacet gatherCraftFacet = new GatherCraftFacet();
        LearnFacet learnFacet = new LearnFacet();
        MapFacet mapFacet = new MapFacet();
        RoleFacet roleFacet = new RoleFacet();
        SocialFacet socialFacet = new SocialFacet();

        // Build Diamond Cut
        AgentboxDiamond.FacetCut[] memory cuts = new AgentboxDiamond.FacetCut[](7);
        
        bytes4[] memory adminSelectors = new bytes4[](7);
        adminSelectors[0] = AdminFacet.initialize.selector;
        adminSelectors[1] = AdminFacet.withdrawEth.selector;
        adminSelectors[2] = AdminFacet.setResourcePoint.selector;
        adminSelectors[3] = AdminFacet.setSkillBlocks.selector;
        adminSelectors[4] = AdminFacet.setNPC.selector;
        adminSelectors[5] = AdminFacet.setRecipe.selector;
        adminSelectors[6] = AdminFacet.setEquipmentConfig.selector;
        cuts[0] = AgentboxDiamond.FacetCut({facetAddress: address(adminFacet), action: AgentboxDiamond.FacetCutAction.Add, functionSelectors: adminSelectors});

        bytes4[] memory actionSelectors = new bytes4[](5);
        actionSelectors[0] = ActionFacet.move.selector;
        actionSelectors[1] = ActionFacet.startMove.selector;
        actionSelectors[2] = ActionFacet.finishMove.selector;
        actionSelectors[3] = ActionFacet.attack.selector;
        actionSelectors[4] = IAgentboxCore.processRespawn.selector;
        cuts[1] = AgentboxDiamond.FacetCut({facetAddress: address(actionFacet), action: AgentboxDiamond.FacetCutAction.Add, functionSelectors: actionSelectors});

        bytes4[] memory gatherCraftSelectors = new bytes4[](7);
        gatherCraftSelectors[0] = GatherCraftFacet.gather.selector;
        gatherCraftSelectors[1] = GatherCraftFacet.startGather.selector;
        gatherCraftSelectors[2] = GatherCraftFacet.finishGather.selector;
        gatherCraftSelectors[3] = GatherCraftFacet.startCrafting.selector;
        gatherCraftSelectors[4] = GatherCraftFacet.finishCrafting.selector;
        gatherCraftSelectors[5] = GatherCraftFacet.equip.selector;
        gatherCraftSelectors[6] = GatherCraftFacet.unequip.selector;
        cuts[2] = AgentboxDiamond.FacetCut({facetAddress: address(gatherCraftFacet), action: AgentboxDiamond.FacetCutAction.Add, functionSelectors: gatherCraftSelectors});

        bytes4[] memory learnSelectors = new bytes4[](4);
        learnSelectors[0] = LearnFacet.startLearning.selector;
        learnSelectors[1] = LearnFacet.startLearningFromPlayer.selector;
        learnSelectors[2] = LearnFacet.finishLearning.selector;
        learnSelectors[3] = IAgentboxCore.processNPCRefresh.selector;
        cuts[3] = AgentboxDiamond.FacetCut({facetAddress: address(learnFacet), action: AgentboxDiamond.FacetCutAction.Add, functionSelectors: learnSelectors});

        bytes4[] memory mapSelectors = new bytes4[](4);
        mapSelectors[0] = MapFacet.getEntityPosition.selector;
        mapSelectors[1] = MapFacet.buyLand.selector;
        mapSelectors[2] = MapFacet.sellLand.selector;
        mapSelectors[3] = MapFacet.setLandContract.selector;
        cuts[4] = AgentboxDiamond.FacetCut({facetAddress: address(mapFacet), action: AgentboxDiamond.FacetCutAction.Add, functionSelectors: mapSelectors});

        bytes4[] memory roleSelectors = new bytes4[](2);
        roleSelectors[0] = RoleFacet.registerCharacter.selector;
        roleSelectors[1] = IAgentboxCore.processSpawn.selector;
        cuts[5] = AgentboxDiamond.FacetCut({facetAddress: address(roleFacet), action: AgentboxDiamond.FacetCutAction.Add, functionSelectors: roleSelectors});

        bytes4[] memory socialSelectors = new bytes4[](2);
        socialSelectors[0] = SocialFacet.sendMessage.selector;
        socialSelectors[1] = SocialFacet.sendGlobalMessage.selector;
        cuts[6] = AgentboxDiamond.FacetCut({facetAddress: address(socialFacet), action: AgentboxDiamond.FacetCutAction.Add, functionSelectors: socialSelectors});

        // Execute Cut
        diamond.diamondCut(cuts);

        // Initialize Core via Diamond
        core = IAgentboxCore(address(diamond));
        core.initialize(address(roleToken), address(config), address(economy), address(randomizer), address(resource));
        
        // Set GameCore references
        resource.setGameCore(address(core));
        randomizer.setGameCore(address(core));
        economy.setGameCore(address(core));
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
