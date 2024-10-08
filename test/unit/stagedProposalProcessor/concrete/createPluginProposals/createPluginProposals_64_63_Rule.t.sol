// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.8;

import {BaseTest} from "../../../../BaseTest.t.sol";
import {Errors} from "../../../../../src/libraries/Errors.sol";
import {PluginA} from "../../../../utils/dummy-plugins/PluginA.sol";
import {SppHarness} from "../../../../utils/harness/SppHarness.sol";
import {TrustedForwarder} from "../../../../../src/utils/TrustedForwarder.sol";
import {GasExpensivePlugin} from "../../../../utils/dummy-plugins/GasExpensivePlugin.sol";
import {StagedProposalProcessor as SPP} from "../../../../../src/StagedProposalProcessor.sol";

contract CreatePluginProposals_64_63_Rule is BaseTest {
    uint256 proposalId;
    SppHarness sppHarness;

    function setUp() public override {
        super.setUp();

        // cast spp to spp harness
        sppHarness = SppHarness(address(sppPlugin));

        // set up stages
        SPP.Stage[] memory stages = _setUpStages();
        sppPlugin.updateStages(stages);

        // create a proposal
        proposalId = sppHarness.createProposal({
            _actions: _createDummyActions(),
            _allowFailureMap: 0,
            _metadata: DUMMY_METADATA,
            _startDate: START_DATE,
            _data: defaultCreationParams
        });
    }

    function test_RevertWhen_CreatingPluginProposalAnd_6364_Rule() external {
        // it should revert.

        uint256 gasBefore = gasleft();
        sppHarness.exposed_createPluginProposals({
            _proposalId: proposalId,
            _stageId: 1,
            _startDate: uint64(block.timestamp),
            _createProposalParams: new bytes[](0)
        });
        uint256 gasAfter = gasleft();

        uint256 expectedGas = gasBefore - gasAfter;

        // deploy again the contracts to cool the warmed storage
        // todo use vm.cool when is life
        setUp();
        // vm.cool(address(this));

        vm.expectRevert(abi.encodeWithSelector(Errors.InsufficientGas.selector));

        sppHarness.exposed_createPluginProposals{gas: expectedGas - 19000}({
            _proposalId: proposalId,
            _stageId: 1,
            _startDate: uint64(block.timestamp),
            _createProposalParams: new bytes[](0)
        });
    }

    // override function in BaseTest
    function _setupDaoAndPluginHelper() internal override {
        address sppAddress = address(new SppHarness());
        _setUpDaoAndPlugin(sppAddress);
    }

    function _setUpStages() internal returns (SPP.Stage[] memory stages) {
        address _plugin1 = address(new PluginA(address(trustedForwarder)));
        address _plugin2 = address(new GasExpensivePlugin(address(trustedForwarder)));

        SPP.Plugin[] memory _plugins1 = new SPP.Plugin[](1);
        _plugins1[0] = _createPluginStruct({_pluginAddr: _plugin1, _isManual: false});

        SPP.Plugin[] memory _plugins2 = new SPP.Plugin[](1);
        _plugins2[0] = _createPluginStruct({_pluginAddr: _plugin2, _isManual: false});

        stages = new SPP.Stage[](2);
        for (uint i; i < 2; ++i) {
            if (i == 0) stages[i] = _createStageStruct(_plugins1);
            else stages[i] = _createStageStruct(_plugins2);
        }
    }
}
