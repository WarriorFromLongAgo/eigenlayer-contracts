using EigenPodManagerHarness as EigenPodManagerHarnessAlias;
using StrategyManagerHarness as StrategyManagerHarnessAlias;
using DummyEigenPodA as DummyEigenPodAAlias;
using DummyEigenPodB as DummyEigenPodBAlias;
using DummyERC20A as DummyERC20AAlias;
using DummyERC20B as DummyERC20BAlias;
using DelegationManagerHarness as DelegationManagerHarnessAlias;
using EigenStrategy as EigenStrategyAlias;
//using PausableHarness as PausableHarnessAlias;
using Pausable as PausableHarnessAlias;
using ETHPOSDepositMock as ETHPOSDepositMockAlias;
using ERC1271WalletMock as ERC1271WalletMockAlias;
using PauserRegistry as PauserRegistryAlias;

methods {
    
	// summarize the deployment of EigenPods to avoid default, HAVOC behavior
    function _.deploy(uint256, bytes32, bytes memory bytecode) internal => NONDET;
    
	// IEigenPod
    function _.withdrawRestakedBeaconChainETH(address, uint256) external => DISPATCHER(true);
    function _.initialize(address) external => DISPATCHER(true);
    function _.stake(bytes, bytes, bytes32) external => DISPATCHER(true);
	    
    function _._ external => DISPATCH [
      DummyEigenPodA.initialize(address),
      DummyEigenPodA.stake(bytes, bytes, bytes32),
      EigenPodManagerHarness.recordBeaconChainETHBalanceUpdate(address, int256),

	  DummyEigenPodB.initialize(address),
      DummyEigenPodB.stake(bytes, bytes, bytes32),
   ] default NONDET;

    // summarizing calls to BeaconChainProofs
    // otherwise it gives trouble to the prover as it requires very large arrays length
    function BeaconChainProofs.verifyStateRoot(bytes32, BeaconChainProofs.StateRootProof calldata) internal => NONDET;
    function BeaconChainProofs.verifyValidatorFields(bytes32, bytes32[] calldata, bytes calldata, uint40) internal => NONDET;
    function BeaconChainProofs.verifyBalanceContainer(bytes32, BeaconChainProofs.BalanceContainerProof calldata) internal => NONDET;
    function BeaconChainProofs.verifyValidatorBalance(bytes32, uint40, BeaconChainProofs.BalanceProof calldata) 
        internal returns (uint64) => NONDET;

    // IERC1271
    function _.isValidSignature(bytes32, bytes) external => DISPATCHER(true); 

    // IStrategy
    function _.withdraw(address, address, uint256) external => DISPATCHER(true);
    function _.deposit(address, uint256) external => DISPATCHER(true);

    // PauserRegistry
    //function _.isPauser(address) external => DISPATCHER(true);    //no longer needed
    //function _.unpauser() external  => DISPATCHER(true);          //no longer needed

    // IETHPOSDeposit
    //function _.deposit(bytes, bytes, bytes, bytes32) external => DISPATCHER(true);
	function _.deposit(bytes, bytes, bytes, bytes32) external => NONDET;


	// Address
	function _.sendValue(address, uint256) internal => NONDET;

	// external calls to DelegationManager 
    function _.undelegate(address) external => DISPATCHER(true);
    function _.decreaseDelegatedShares(address,address,uint256) external => DISPATCHER(true);
	function _.increaseDelegatedShares(address,address,uint256) external => DISPATCHER(true);


    // external calls from DelegationManager to ServiceManager
    function _.updateStakes(address[]) external => NONDET;

	// external calls to Slasher
    function _.isFrozen(address) external => NONDET; //DISPATCHER(true);
	function _.canWithdraw(address,uint32,uint256) external => NONDET; //DISPATCHER(true);

	// external calls to StrategyManager
    function _.getDeposits(address) external => DISPATCHER(true);
    function _.slasher() external => DISPATCHER(true);
    function _.addShares(address,address,address,uint256) external => DISPATCHER(true);
    function _.removeShares(address,address,uint256) external => DISPATCHER(true);
    function _.withdrawSharesAsTokens(address, address, uint256, address) external => DISPATCHER(true);


	/////  EigenPodManager ///////////////

	// external calls to EigenPodManager
    function _.addShares(address,uint256) external => DISPATCHER(true);
    function _.removeShares(address,uint256) external => DISPATCHER(true);
    function _.withdrawSharesAsTokens(address, address, uint256) external => DISPATCHER(true);
	//function _.podOwnerShares(address) external => DISPATCHER(true);
	function _.recordBeaconChainETHBalanceUpdate(address, int256) external => DISPATCHER(true);

    // envfree functions
    function EigenPodManagerHarness.ownerToPod(address podOwner) external returns (address) envfree;
    function EigenPodManagerHarness.getPod(address podOwner) external returns (address) envfree;
    function EigenPodManagerHarness.ethPOS() external returns (address) envfree;
    function EigenPodManagerHarness.eigenPodBeacon() external returns (address) envfree;
    //function EigenPodManagerHarness.beaconChainOracle() external returns (address) envfree;
    //function EigenPodManagerHarness.getBlockRootAtTimestamp(uint64 timestamp) external returns (bytes32) envfree;
    function EigenPodManagerHarness.strategyManager() external returns (address) envfree;
    function EigenPodManagerHarness.slasher() external returns (address) envfree;
    function EigenPodManagerHarness.hasPod(address podOwner) external returns (bool) envfree;
    function EigenPodManagerHarness.numPods() external returns (uint256) envfree;
    function EigenPodManagerHarness.podOwnerShares(address podOwner) external returns (int256) envfree;
    function EigenPodManagerHarness.beaconChainETHStrategy() external returns (address) envfree; 

    // harnessed functions
    function EigenPodManagerHarness.get_podOwnerShares(address) external returns (int256) envfree;
    function EigenPodManagerHarness.get_podByOwner(address) external returns (address) envfree;

    // external calls to ERC20 token
    function _.transfer(address, uint256) external => DISPATCHER(true);
    function _.transferFrom(address, address, uint256) external => DISPATCHER(true);
    function _.approve(address, uint256) external => DISPATCHER(true);
	
	// IEigen
	function _.wrap(uint256) external => NONDET;
	function _.unwrap(uint256) external => NONDET;

}

