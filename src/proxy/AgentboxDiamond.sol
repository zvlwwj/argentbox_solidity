// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../storage/AgentboxStorage.sol";

contract AgentboxDiamond {
    mapping(bytes4 => address) public facets;

    event DiamondCut(FacetCut[] _diamondCut);

    enum FacetCutAction {Add, Replace, Remove}

    struct FacetCut {
        address facetAddress;
        FacetCutAction action;
        bytes4[] functionSelectors;
    }

    modifier onlyOwner() {
        require(msg.sender == AgentboxStorage.getStorage().owner, "Not owner");
        _;
    }

    constructor() {
        AgentboxStorage.getStorage().owner = msg.sender;
    }

    function diamondCut(FacetCut[] calldata _diamondCut) external onlyOwner {
        for (uint256 i = 0; i < _diamondCut.length; i++) {
            FacetCut memory cut = _diamondCut[i];
            for (uint256 j = 0; j < cut.functionSelectors.length; j++) {
                bytes4 selector = cut.functionSelectors[j];
                if (cut.action == FacetCutAction.Add || cut.action == FacetCutAction.Replace) {
                    require(cut.facetAddress != address(0), "Facet cannot be zero");
                    facets[selector] = cut.facetAddress;
                } else if (cut.action == FacetCutAction.Remove) {
                    delete facets[selector];
                }
            }
        }
        emit DiamondCut(_diamondCut);
    }

    fallback() external payable {
        address facet = facets[msg.sig];
        require(facet != address(0), "Diamond: Function does not exist");
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    receive() external payable {}
}
