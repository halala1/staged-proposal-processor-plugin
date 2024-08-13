// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.8;

import {BaseTest} from "../../../BaseTest.t.sol";
import {Errors} from "../../../../src/libraries/Errors.sol";
import {PluginA} from "../../../utils/dummy-plugins/PluginA.sol";
import {StagedProposalProcessor as SPP} from "../../../../src/StagedProposalProcessor.sol";

import {DaoUnauthorized} from "@aragon/osx/core/utils/auth.sol";
import {IDAO} from "@aragon/osx-commons-contracts-new/src/dao/IDAO.sol";
import {PermissionLib} from "@aragon/osx/core/permission/PermissionLib.sol";

contract CreateProposal_SPP_IntegrationTest is BaseTest {
    function test_RevertWhen_CallerIsNotAllowed() external {
        // it should revert.

        resetPrank(users.unauthorized);

        vm.expectRevert(
            abi.encodeWithSelector(
                DaoUnauthorized.selector,
                address(dao),
                address(sppPlugin),
                users.unauthorized,
                sppPlugin.CREATE_PROPOSAL_PERMISSION_ID()
            )
        );
        sppPlugin.createProposal({
            _actions: new IDAO.Action[](0),
            _allowFailureMap: 0,
            _metadata: DUMMY_METADATA,
            _startDate: START_DATE
        });
    }

    modifier whenStagesAreConfigured() {
        _;
    }

    modifier givenSomeSubProposalsOnStageZeroAreNonManual() {
        SPP.Stage[] memory stages = _createDummyStages(2, false, true, false);
        sppPlugin.updateStages(stages);
        _;
    }

    function test_WhenSubProposalCanNotBeCreated()
        external
        whenStagesAreConfigured
        givenSomeSubProposalsOnStageZeroAreNonManual
    {
        // it should emit an event.
        // todo proposals are defined as non-manual but can not be created due to no implement IProposal interface.
        vm.skip(true);
    }

    function test_WhenSubProposalCanBeCreated()
        external
        whenStagesAreConfigured
        givenSomeSubProposalsOnStageZeroAreNonManual
    {
        // it should emit events.
        // it should create proposal.
        // it should create non-manual sub proposals on stage zero.
        // it should not create sub proposals on non zero stages.

        // create proposal
        IDAO.Action[] memory actions = _createDummyActions();

        // check event
        vm.expectEmit({
            checkTopic1: false,
            checkTopic2: true,
            checkTopic3: true,
            checkData: true,
            emitter: address(sppPlugin)
        });
        emit ProposalCreated({
            proposalId: 0,
            creator: users.manager,
            startDate: START_DATE,
            endDate: 0,
            metadata: DUMMY_METADATA,
            actions: actions,
            allowFailureMap: 0
        });
        bytes32 proposalId = sppPlugin.createProposal({
            _actions: actions,
            _allowFailureMap: 0,
            _metadata: DUMMY_METADATA,
            _startDate: START_DATE
        });

        // check proposal
        SPP.Proposal memory proposal = sppPlugin.getProposal(proposalId);
        assertEq(proposal.currentStage, 0, "current stage");
        assertEq(proposal.creator, users.manager, "creator");
        assertEq(proposal.metadata, DUMMY_METADATA, "metadata");
        assertEq(proposal.lastStageTransition, START_DATE, "startDate");
        assertFalse(proposal.executed, "executed");

        // check sub proposals on stage zero
        SPP.Stage[] memory stages = sppPlugin.getStages();
        SPP.Plugin memory _currentPlugin;
        uint256 _currentPluginProposalsCount;
        for (uint256 i; i < stages[0].plugins.length; i++) {
            _currentPlugin = stages[0].plugins[i];
            _currentPluginProposalsCount = PluginA(_currentPlugin.pluginAddress).proposalCount();
            if (_currentPlugin.isManual) {
                // should not be created since it is manual
                assertEq(_currentPluginProposalsCount, 0, "proposalsCount");
            } else {
                // should be created since it is non-manual
                assertEq(_currentPluginProposalsCount, 1, "proposalsCount");
            }
        }

        // check sub proposals on non zero stage
        for (uint256 i; i < stages[1].plugins.length; i++) {
            _currentPlugin = stages[1].plugins[i];
            assertEq(PluginA(_currentPlugin.pluginAddress).proposalCount(), 0, "proposalsCount");
        }
    }

    function test_GivenAllSubProposalOnStageZeroAreManual() external whenStagesAreConfigured {
        // it should emit events.
        // it should create proposal.
        // it should not create sub proposals on stage zero.
        // it should not create sub proposals on non zero stages.

        // configure stages
        SPP.Stage[] memory stages = _createDummyStages(2, true, true, false);
        sppPlugin.updateStages(stages);

        // create proposal
        IDAO.Action[] memory actions = _createDummyActions();

        // check event
        vm.expectEmit({
            checkTopic1: false,
            checkTopic2: true,
            checkTopic3: true,
            checkData: true,
            emitter: address(sppPlugin)
        });
        emit ProposalCreated({
            proposalId: 0,
            creator: users.manager,
            startDate: START_DATE,
            endDate: 0,
            metadata: DUMMY_METADATA,
            actions: actions,
            allowFailureMap: 0
        });

        bytes32 proposalId = sppPlugin.createProposal({
            _actions: actions,
            _allowFailureMap: 0,
            _metadata: DUMMY_METADATA,
            _startDate: START_DATE
        });

        // check proposal
        SPP.Proposal memory proposal = sppPlugin.getProposal(proposalId);
        assertEq(proposal.currentStage, 0, "current stage");
        assertEq(proposal.creator, users.manager, "creator");
        assertEq(proposal.metadata, DUMMY_METADATA, "metadata");
        assertEq(proposal.lastStageTransition, START_DATE, "startDate");
        assertFalse(proposal.executed, "executed");

        // check no sub proposals created
        SPP.Plugin memory _currentPlugin;
        for (uint256 i; i < stages[0].plugins.length; i++) {
            _currentPlugin = stages[0].plugins[i];

            assertTrue(_currentPlugin.isManual, "isManual");
            assertEq(PluginA(_currentPlugin.pluginAddress).proposalCount(), 0, "proposalCount");
        }

        // check no sub proposals created
        for (uint256 i; i < stages[1].plugins.length; i++) {
            assertEq(
                PluginA(stages[1].plugins[i].pluginAddress).proposalCount(),
                0,
                "proposalCount"
            );
        }
    }

    function test_GivenStartDateIsInThePast() external whenStagesAreConfigured {
        // it should use block.timestamp for first stage sub proposal startDate.
        // it should use block.timestamp for last stage transition.

        // block.timestamp is 3 and startDate is 1  1 < 3
        vm.warp(3);

        uint64 _expectedStartDate = uint64(block.timestamp);

        // configure stages
        SPP.Stage[] memory stages = _createDummyStages(2, false, false, false);
        sppPlugin.updateStages(stages);

        // create proposal
        IDAO.Action[] memory actions = _createDummyActions();

        // check proposal start date
        SPP.Plugin memory _currentPlugin;
        for (uint256 i; i < stages[0].plugins.length; i++) {
            _currentPlugin = stages[0].plugins[i];

            vm.expectEmit({emitter: _currentPlugin.pluginAddress});
            emit ProposalCreated({
                proposalId: 0,
                startDate: _expectedStartDate,
                endDate: _expectedStartDate + stages[0].voteDuration
            });
        }

        bytes32 proposalId = sppPlugin.createProposal({
            _actions: actions,
            _allowFailureMap: 0,
            _metadata: DUMMY_METADATA,
            _startDate: 1
        });

        SPP.Proposal memory proposal = sppPlugin.getProposal(proposalId);

        // check proposal last stage transition
        assertEq(proposal.lastStageTransition, _expectedStartDate, "lastStageTransition");
    }

    function test_GivenStartDateInInTheFuture() external whenStagesAreConfigured {
        // it should use block.timestamp for first stage sub proposal startDate.
        // it should use block.timestamp for last stage transition.

        uint64 _expectedStartDate = START_DATE;

        // configure stages
        SPP.Stage[] memory stages = _createDummyStages(2, false, false, false);
        sppPlugin.updateStages(stages);

        // create proposal
        IDAO.Action[] memory actions = _createDummyActions();

        // check proposal start date
        SPP.Plugin memory _currentPlugin;
        for (uint256 i; i < stages[0].plugins.length; i++) {
            _currentPlugin = stages[0].plugins[i];

            vm.expectEmit({emitter: _currentPlugin.pluginAddress});
            emit ProposalCreated({
                proposalId: 0,
                startDate: _expectedStartDate,
                endDate: _expectedStartDate + stages[0].voteDuration
            });
        }

        bytes32 proposalId = sppPlugin.createProposal({
            _actions: actions,
            _allowFailureMap: 0,
            _metadata: DUMMY_METADATA,
            _startDate: START_DATE
        });

        SPP.Proposal memory proposal = sppPlugin.getProposal(proposalId);

        // check proposal last stage transition
        assertEq(proposal.lastStageTransition, _expectedStartDate, "lastStageTransition");
    }

    function test_RevertWhen_StagesAreNotConfigured() external {
        // it should revert.

        vm.expectRevert(abi.encodeWithSelector(Errors.StageCountZero.selector));
        sppPlugin.createProposal({
            _actions: new IDAO.Action[](0),
            _allowFailureMap: 0,
            _metadata: DUMMY_METADATA,
            _startDate: START_DATE
        });
    }
}
