// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/AgentboxRoleWallet.sol";
import "../src/AgentboxRole.sol";
import "../src/AgentboxConfig.sol";
import "../src/AgentboxResource.sol";
import "../src/AgentboxEconomy.sol";
import "../src/AgentboxRandomizer.sol";
import "../src/proxy/AgentboxDiamond.sol";
import "../src/facets/AdminFacet.sol";
import "../src/facets/ActionFacet.sol";
import "../src/facets/GatherCraftFacet.sol";
import "../src/facets/LearnFacet.sol";
import "../src/facets/MapFacet.sol";
import "../src/facets/RoleFacet.sol";
import "../src/facets/SocialFacet.sol";
import "../src/interfaces/IAgentboxCore.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        address vrfCoordinator = vm.envAddress("VRF_COORDINATOR");
        bytes32 keyHash = vm.envBytes32("VRF_KEY_HASH");
        uint64 subscriptionId = uint64(vm.envUint("VRF_SUB_ID"));

        vm.startBroadcast(deployerPrivateKey);

        AgentboxConfig config = new AgentboxConfig();
        AgentboxRoleWallet walletImpl = new AgentboxRoleWallet();
        AgentboxRole role = new AgentboxRole(address(walletImpl));
        AgentboxResource resource = new AgentboxResource();
        AgentboxRandomizer randomizer = new AgentboxRandomizer(vrfCoordinator, keyHash, subscriptionId);
        AgentboxEconomy economy = new AgentboxEconomy(address(config), vrfCoordinator, keyHash, subscriptionId);

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

        bytes4[] memory actionSelectors = new bytes4[](4);
        actionSelectors[0] = ActionFacet.move.selector;
        actionSelectors[1] = ActionFacet.startMove.selector;
        actionSelectors[2] = ActionFacet.finishMove.selector;
        actionSelectors[3] = ActionFacet.attack.selector;
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
        learnSelectors[3] = LearnFacet.processNPCRefresh.selector;
        cuts[3] = AgentboxDiamond.FacetCut({facetAddress: address(learnFacet), action: AgentboxDiamond.FacetCutAction.Add, functionSelectors: learnSelectors});

        bytes4[] memory mapSelectors = new bytes4[](4);
        mapSelectors[0] = MapFacet.getEntityPosition.selector;
        mapSelectors[1] = MapFacet.buyLand.selector;
        mapSelectors[2] = MapFacet.sellLand.selector;
        mapSelectors[3] = MapFacet.setLandContract.selector;
        cuts[4] = AgentboxDiamond.FacetCut({facetAddress: address(mapFacet), action: AgentboxDiamond.FacetCutAction.Add, functionSelectors: mapSelectors});

        bytes4[] memory roleSelectors = new bytes4[](3);
        roleSelectors[0] = RoleFacet.registerCharacter.selector;
        roleSelectors[1] = RoleFacet.processSpawn.selector;
        roleSelectors[2] = RoleFacet.processRespawn.selector;
        cuts[5] = AgentboxDiamond.FacetCut({facetAddress: address(roleFacet), action: AgentboxDiamond.FacetCutAction.Add, functionSelectors: roleSelectors});

        bytes4[] memory socialSelectors = new bytes4[](2);
        socialSelectors[0] = SocialFacet.sendMessage.selector;
        socialSelectors[1] = SocialFacet.sendGlobalMessage.selector;
        cuts[6] = AgentboxDiamond.FacetCut({facetAddress: address(socialFacet), action: AgentboxDiamond.FacetCutAction.Add, functionSelectors: socialSelectors});

        // Execute Cut
        diamond.diamondCut(cuts);

        // Initialize Core via Diamond
        IAgentboxCore core = IAgentboxCore(address(diamond));
        core.initialize(address(role), address(config), address(economy), address(randomizer), address(resource));
        
        // Set GameCore references
        resource.setGameCore(address(core));
        randomizer.setGameCore(address(core));
        economy.setGameCore(address(core));

        vm.stopBroadcast();
        
        console.log("=== Deployment Successful ===");
        console.log("Config:", address(config));
        console.log("Role (NFT):", address(role));
        console.log("Resource (ERC1155):", address(resource));
        console.log("Randomizer:", address(randomizer));
        console.log("Economy (ERC20):", address(economy));
        console.log("Core (Diamond):", address(core));
        console.log("============================");
    }
}
