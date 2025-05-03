// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IAdminGovHooks
 * @dev Interface for admin governance hooks
 * Defines callbacks that DOVEGovernance will call on the admin contract
 */
interface IAdminGovHooks {
    /**
     * @dev Called once just after a proposal is stored in Governance
     * @param proposalId ID of the proposal
     * @param proposedAdmin Address of the proposed admin
     */
    function _gov_onProposalCreated(
        uint256 proposalId,
        address proposedAdmin
    ) external;

    /**
     * @dev Called by Governance once enough approvals are collected
     * @param proposalId ID of the proposal
     * @param proposedAdmin Address of the proposed admin
     */
    function _gov_onProposalExecuted(
        uint256 proposalId,
        address proposedAdmin
    ) external;
}
