// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title DOVELiquidityManager (Stub)
 * @dev Minimal placeholder contract used only for compilation of legacy artifacts.
 */
contract DOVELiquidityManager {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function dummy() external view returns (address) {
        return owner;
    }
}
