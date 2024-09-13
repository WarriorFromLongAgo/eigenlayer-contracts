// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "../interfaces/IStrategyManager.sol";
import "../interfaces/IDelegationManager.sol";
import "../interfaces/ISlasher.sol";
import "../interfaces/IAVSDirectory.sol";
import "../interfaces/IEigenPodManager.sol";
import "../interfaces/IAllocationManager.sol";

/**
 * @title Storage variables for the `DelegationManager` contract.
 * @author Layr Labs, Inc.
 * @notice Terms of Service: https://docs.eigenlayer.xyz/overview/terms-of-service
 * @notice This storage contract is separate from the logic to simplify the upgrade process.
 */
abstract contract DelegationManagerStorage is IDelegationManager {
    /// @notice The EIP-712 typehash for the contract's domain
    bytes32 public constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    /// @notice The EIP-712 typehash for the `StakerDelegation` struct used by the contract
    bytes32 public constant STAKER_DELEGATION_TYPEHASH =
        keccak256("StakerDelegation(address staker,address operator,uint256 nonce,uint256 expiry)");

    /// @notice The EIP-712 typehash for the `DelegationApproval` struct used by the contract
    bytes32 public constant DELEGATION_APPROVAL_TYPEHASH = keccak256(
        "DelegationApproval(address delegationApprover,address staker,address operator,bytes32 salt,uint256 expiry)"
    );

    /// @notice Minimum withdrawal delay in seconds until all queued withdrawals can be completed.
    uint32 public immutable MIN_WITHDRAWAL_DELAY;

    /**
     * @notice Original EIP-712 Domain separator for this contract.
     * @dev The domain separator may change in the event of a fork that modifies the ChainID.
     * Use the getter function `domainSeparator` to get the current domain separator for this contract.
     */
    bytes32 internal _DOMAIN_SEPARATOR;

    /// @notice The AVSDirectory contract for EigenLayer
    IAVSDirectory public immutable avsDirectory;

    /// @notice The StrategyManager contract for EigenLayer
    IStrategyManager public immutable strategyManager;

    /// @notice The Slasher contract for EigenLayer
    ISlasher public immutable slasher;

    /// @notice The EigenPodManager contract for EigenLayer
    IEigenPodManager public immutable eigenPodManager;

    /// @notice The AllocationManager contract for EigenLayer
    IAllocationManager public immutable allocationManager;

    /**
     * @notice returns the total number of scaled shares (i.e. shares scaled down by a factor of the `operator`'s
     * totalMagnitude) in `strategy` that are delegated to `operator`.
     * @notice Mapping: operator => strategy => total number of scaled shares in the strategy delegated to the operator.
     * @dev By design, the following invariant should hold for each Strategy:
     * (operator's scaled shares in delegation manager) = sum (scaled shares above zero of all stakers delegated to operator)
     * = sum (delegateable scaled shares of all stakers delegated to the operator)
     * @dev FKA `operatorShares`
     */
    mapping(address => mapping(IStrategy => uint256)) public operatorScaledShares;

    /**
     * @notice Mapping: operator => OperatorDetails struct
     * @dev This struct is internal with an external getter so we can return an `OperatorDetails memory` object
     */
    mapping(address => OperatorDetails) internal _operatorDetails;

    /**
     * @notice Mapping: staker => operator whom the staker is currently delegated to.
     * @dev Note that returning address(0) indicates that the staker is not actively delegated to any operator.
     */
    mapping(address => address) public delegatedTo;

    /// @notice Mapping: staker => number of signed messages (used in `delegateToBySignature`) from the staker that this contract has already checked.
    mapping(address => uint256) public stakerNonce;

    /**
     * @notice Mapping: delegationApprover => 32-byte salt => whether or not the salt has already been used by the delegationApprover.
     * @dev Salts are used in the `delegateTo` and `delegateToBySignature` functions. Note that these functions only process the delegationApprover's
     * signature + the provided salt if the operator being delegated to has specified a nonzero address as their `delegationApprover`.
     */
    mapping(address => mapping(bytes32 => bool)) public delegationApproverSaltIsSpent;

    /**
     * @notice Global minimum withdrawal delay for all strategy withdrawals.
     * In a prior Goerli release, we only had a global min withdrawal delay across all strategies.
     * In addition, we now also configure withdrawal delays on a per-strategy basis.
     * To withdraw from a strategy, max(minWithdrawalDelayBlocks, strategyWithdrawalDelayBlocks[strategy]) number of blocks must have passed.
     * See mapping strategyWithdrawalDelayBlocks below for per-strategy withdrawal delays.
     */
    uint256 private __deprecated_minWithdrawalDelayBlocks;

    /// @notice Mapping: hash of withdrawal inputs, aka 'withdrawalRoot' => whether the withdrawal is pending
    mapping(bytes32 => bool) public pendingWithdrawals;

    /// @notice Mapping: staker => cumulative number of queued withdrawals they have ever initiated.
    /// @dev This only increments (doesn't decrement), and is used to help ensure that otherwise identical withdrawals have unique hashes.
    mapping(address => uint256) public cumulativeWithdrawalsQueued;

    /// @notice Deprecated from an old Goerli release
    /// See conversation here: https://github.com/Layr-Labs/eigenlayer-contracts/pull/365/files#r1417525270
    address private __deprecated_stakeRegistry;

    /**
     * @notice Minimum delay enforced by this contract per Strategy for completing queued withdrawals. Measured in blocks, and adjustable by this contract's owner,
     * up to a maximum of `MAX_WITHDRAWAL_DELAY_BLOCKS`. Minimum value is 0 (i.e. no delay enforced).
     */
    mapping(IStrategy => uint256) private __deprecated_strategyWithdrawalDelayBlocks;

    /// @notice Mapping: staker => strategy => scaling factor used to calculate the staker's withdrawable shares in the strategy.
    /// This is updated upon each deposit based on the staker's currently delegated operator's totalMagnitude.
    mapping(address => mapping(IStrategy => uint256)) public stakerScalingFactors;

    /// @notice Mapping: operator => allocation delay (in seconds) for the operator.
    /// This determines how long it takes for allocations to take effect in the future. Can only be set one time for each operator
    mapping(address => AllocationDelayDetails) internal _operatorAllocationDelay;

    constructor(
        IStrategyManager _strategyManager,
        ISlasher _slasher,
        IEigenPodManager _eigenPodManager,
        IAVSDirectory _avsDirectory,
        IAllocationManager _allocationManager,
        uint32 _MIN_WITHDRAWAL_DELAY
    ) {
        strategyManager = _strategyManager;
        eigenPodManager = _eigenPodManager;
        slasher = _slasher;
        avsDirectory = _avsDirectory;
        allocationManager = _allocationManager;
        MIN_WITHDRAWAL_DELAY = _MIN_WITHDRAWAL_DELAY;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[37] private __gap;
}
