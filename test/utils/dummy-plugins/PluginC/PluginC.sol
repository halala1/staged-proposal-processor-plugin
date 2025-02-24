// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.8;

import {TrustedForwarder} from "../../../../src/utils/TrustedForwarder.sol";

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Action} from "@aragon/osx-commons-contracts/src/executors/IExecutor.sol";
import {
    IProposal
} from "@aragon/osx-commons-contracts/src/plugin/extensions/proposal/IProposal.sol";

// dummy plugin that implements IProposal but the create function always reverts
contract PluginC is IProposal, IERC165 {
    bool public created;
    uint256 public proposalId;
    TrustedForwarder public trustedForwarder;
    mapping(uint256 => Action) public actions;

    constructor(address _trustedForwarder) {
        trustedForwarder = TrustedForwarder(_trustedForwarder);
    }

    function supportsInterface(bytes4 _interfaceId) public view virtual override returns (bool) {
        return
            _interfaceId == type(IProposal).interfaceId ||
            _interfaceId == type(IERC165).interfaceId;
    }

    function createProposal(
        bytes calldata,
        Action[] calldata,
        uint64,
        uint64,
        bytes memory
    ) external pure override returns (uint256) {
        revert("Always reverts");
    }

    function customProposalParamsABI() external pure override returns (string memory) {
        return "";
    }

    function canExecute(uint256) public pure returns (bool) {
        // TODO: for now
        return true;
    }

    function execute(
        uint256 _proposalId
    ) external returns (bytes[] memory execResults, uint256 failureMap) {
        Action[] memory mainActions = new Action[](1);
        mainActions[0] = actions[_proposalId];
        (execResults, failureMap) = trustedForwarder.execute(bytes32(_proposalId), mainActions, 0);
    }

    function proposalCount() external view override returns (uint256) {
        return proposalId;
    }
}
