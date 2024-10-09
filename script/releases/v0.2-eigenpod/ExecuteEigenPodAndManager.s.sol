// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.12;

import "script/Release_Template.s.sol";
import {IUpgradeableBeacon} from "script/utils/Interfaces.sol";

import "src/contracts/interfaces/IStrategyFactory.sol";
import "src/contracts/pods/EigenPodManager.sol";

import "./QueueEigenPodAndManager.s.sol";

contract ExecuteEigenPodAndManager is MultisigBuilder {

    using MultisigCallUtils for MultisigCall[];
    using TransactionHelper for Transaction;

    MultisigCall[] internal _opsCalls;

    function _execute(Addresses memory addrs, Environment memory env, Params memory params) internal override returns (MultisigCall[] memory) {

        QueueEigenPodAndManager queue = new QueueEigenPodAndManager();

        MultisigCall[] memory _executorCalls = queue._queue(addrs, env, params);

        bytes memory executorCalldata = queue.makeExecutorCalldata(
            _executorCalls,
            params.multiSendCallOnly,
            addrs.timelock
        );

        // execute queued transaction upgrading eigenPodManager and eigenPod
        _opsCalls.append({
            to: addrs.timelock,
            value: 0,
            data: abi.encodeWithSelector(
                ITimelock.executeTransaction.selector,
                executorCalldata
            )
        });

        // after queued transaction, renounce ownership from eigenPodManager
        _opsCalls.append({
            to: addrs.eigenPodManager.proxy,
            value: 0,
            data: abi.encodeWithSelector(
                EigenPodManager(addrs.eigenPodManager.proxy).renounceOwnership.selector
            )
        });

        return _opsCalls;
    }

    function _testExecute(
        Addresses memory addrs,
        Environment memory env,
        Params memory params
    ) internal override {
        bytes memory data = _opsCalls.encodeMultisendTxs();

        vm.startBroadcast(addrs.operationsMultisig);
        params.multiSendCallOnly.delegatecall(data);
        vm.stopBroadcast();
    }
}
