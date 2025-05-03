// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../token/DOVE.sol";
import "../token/DOVEEvents.sol";
import "../token/DOVEInfo.sol";
import "../admin/DOVEGovernance.sol";

/**
 * @title DOVEDeployer
 * @dev Factory contract for deploying and initializing the DOVE token ecosystem
 * This contract ensures proper initialization sequence and prevents circular dependencies
 */
contract DOVEDeployer {
    /**
     * @dev Emitted when a DOVE ecosystem is deployed
     * @param dove Address of deployed DOVE token
     * @param events Address of deployed DOVEEvents
     * @param info Address of deployed DOVEInfo
     * @param governance Address of deployed DOVEGovernance
     * @param deployer Address that deployed the system
     */
    event DOVEEcosystemDeployed(
        address indexed dove,
        address indexed events,
        address info,
        address governance,
        address deployer
    );
    
    /**
     * @dev Deploy the complete DOVE token ecosystem
     * @param adminContract Address of the admin contract
     * @param charityWallet Initial charity wallet address
     * @return dove Address of the deployed DOVE token
     * @return events Address of the deployed DOVEEvents contract
     * @return info Address of the deployed DOVEInfo contract
     * @return governance Address of the deployed DOVEGovernance contract
     */
    function deployDOVEEcosystem(
        address adminContract,
        address charityWallet
    ) external returns (
        address dove,
        address events,
        address info,
        address governance
    ) {
        // Step 1: Deploy independent contracts
        DOVEEvents eventsContract = new DOVEEvents();
        DOVEGovernance governanceContract = new DOVEGovernance();
        
        // Step 2: Deploy main DOVE token with minimal dependencies
        DOVE doveToken = new DOVE(adminContract, charityWallet);
        
        // Step 3: Get fee manager address from DOVE token
        address feeManager = doveToken.getFeeManager();
        
        // Step 4: Deploy DOVEInfo with all necessary information
        DOVEInfo infoContract = new DOVEInfo();
        
        // Step 5: Initialize contracts in correct order to avoid circular dependencies
        bool eventsInitialized = eventsContract.initialize(address(doveToken));
        require(eventsInitialized, "Events initialization failed");
        
        bool governanceInitialized = governanceContract.initialize(adminContract);
        require(governanceInitialized, "Governance initialization failed");
        
        bool infoInitialized = infoContract.initialize(
            address(doveToken),
            feeManager,
            address(governanceContract),
            doveToken.TOTAL_SUPPLY() / 100 // 1% of total supply
        );
        require(infoInitialized, "Info initialization failed");
        
        // Step 6: Finally, set all secondary contracts on the DOVE token
        bool doveInitialized = doveToken.setSecondaryContracts(
            address(eventsContract),
            address(governanceContract),
            address(infoContract)
        );
        require(doveInitialized, "DOVE initialization failed");
        
        // Emit deployment event
        emit DOVEEcosystemDeployed(
            address(doveToken),
            address(eventsContract),
            address(infoContract),
            address(governanceContract),
            msg.sender
        );
        
        return (
            address(doveToken),
            address(eventsContract),
            address(infoContract),
            address(governanceContract)
        );
    }
    
    /**
     * @dev Verify that the DOVE ecosystem is properly initialized
     * @param dove Address of the DOVE token
     * @return True if the ecosystem is properly initialized
     */
    function verifyEcosystemInitialization(address dove) external view returns (bool) {
        return DOVE(dove).isFullyInitialized();
    }
}
