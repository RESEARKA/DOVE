# DOVE Token - New Architecture Design

## Overview
DOVE is an ERC-20 token with charity fee and early sell tax mechanics. This document outlines the simplified architecture based on lessons learned from the previous implementation.

## Core Components

### 1. Token Contract (DOVE.sol)
- **Purpose**: Core ERC-20 implementation with direct fee calculation
- **Inheritance**: OpenZeppelin ERC20, AccessControl (2 levels max)
- **Key Features**:
  - Inline fee calculation (0.5% charity fee)
  - Early sell tax mechanism (decreasing over time)
  - Transfer hooks for fee collection
  - Max transaction limits
  - Role-based security checks

### 2. Admin Contract (DOVEAdmin.sol)
- **Purpose**: Administrative functions and centralized role management
- **Inheritance**: AccessControl
- **Key Features**:
  - Launch functionality
  - Fee exclusion management
  - DEX address management
  - Emergency controls (pause, max tx limits)
  - Optional multisig for critical operations

### 3. Interfaces
- **IDOVE.sol**: Token interface with fee methods
- **IDOVEAdmin.sol**: Admin interface for external interactions

## Architecture Principles

1. **Minimal Inheritance**: Maximum 2-3 inheritance levels
2. **Clear Separation**: Each contract has a single, focused responsibility
3. **Independent Deployability**: No circular dependencies
4. **Centralized Role Management**: Single source of truth for roles
5. **Inline Fee Logic**: Fee calculation contained within DOVE.sol
6. **Two-Phase Initialization**: Optional use of initialize patterns instead of constructors
7. **Event-Driven Tracking**: All state changes emit events

## State Management
- Constant values (BASIS_POINTS, CHARITY_FEE) defined in DOVE.sol
- Address mappings (excluded from fees, known DEXes) in DOVE.sol
- Role definitions centralized in DOVEAdmin.sol

## Deployment Sequence
1. Deploy DOVEAdmin.sol
2. Deploy DOVE.sol with admin address
3. Grant necessary roles via DOVEAdmin
4. Initialize system (no circular references)

## Test Strategy
- Use fixtures matching real deployment sequence
- Accurate address handling (getAddress)
- Proper assertion syntax (rejectedWith for async)
- Comprehensive tests for fee mechanics
