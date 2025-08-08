# TrustBridge Smart Contract

**A decentralized work agreement platform with phase-based payment releases and arbitration support on the Stacks blockchain.**

## Overview

TrustBridge enables secure, trustless work agreements between employers and contractors through automated escrow and milestone-based payments. The platform eliminates payment disputes by holding funds in smart contract escrow and releasing them only upon completion and approval of predefined work phases.

## Key Features

- **Escrow Protection**: Funds are locked in the contract until work phases are completed
- **Phase-Based Payments**: Break large projects into manageable phases with individual deliverables
- **Built-in Arbitration**: Neutral third-party dispute resolution system
- **Automated Releases**: Smart contract handles all payment distributions
- **Full Transparency**: All agreement terms and progress tracked on-chain

## Core Workflow

1. **Employer creates work agreement** - Deposits full payment amount and defines project phases
2. **Contractor accepts agreement** - Commits to delivering the specified work
3. **Phase-by-phase delivery** - Contractor submits deliverables for each phase
4. **Approval & payment** - Employer approves work and payment is automatically released
5. **Dispute resolution** - If issues arise, arbitrator can redistribute remaining funds

## Smart Contract Functions

### Agreement Management
- `create-work-agreement` - Create new work agreement with escrow deposit
- `accept-work-agreement` - Contractor accepts and commits to agreement
- `define-work-phase` - Employer sets up individual work phases

### Work Delivery
- `submit-phase-delivery` - Contractor submits completed work with proof
- `approve-phase-delivery` - Employer approves work and triggers payment release

### Dispute Resolution
- `initiate-arbitration` - Either party can start dispute resolution process
- `resolve-arbitration-case` - Arbitrator redistributes funds based on case evaluation

### Information Queries
- `get-agreement-info` - Retrieve agreement details and current status
- `get-phase-info` - Get specific phase information and delivery status
- `get-treasury-info` - Check current escrow balance and released amounts

## Agreement Statuses

- **open** - Agreement created, waiting for contractor
- **in-progress** - Contractor accepted, work is ongoing
- **disputed** - Arbitration process initiated
- **resolved** - Dispute resolved by arbitrator

## Phase Statuses

- **pending** - Phase defined, waiting for contractor delivery
- **submitted** - Contractor submitted deliverables, awaiting approval
- **completed** - Employer approved phase, payment released

## Fee Structure

- **Arbitration Fee**: 5% of total agreement value (paid to arbitrator only if dispute occurs)
- **Platform Fee**: None (completely decentralized)

## Security Features

- **Access Control**: Only authorized parties can perform specific actions
- **Fund Safety**: All payments held in contract escrow until legitimately released
- **Dispute Protection**: Either party can initiate arbitration if needed
- **Validation Checks**: Comprehensive input validation and state verification

## Usage Example

```clarity
;; 1. Employer creates 1000 STX agreement with 3 phases
(create-work-agreement "Website Development Project" u1000000000 u3 'SP2ARBITRATOR...)

;; 2. Define first phase (300 STX for wireframes)
(define-work-phase u1 u0 u300000000 "Complete wireframes and mockups")

;; 3. Contractor accepts the agreement
(accept-work-agreement u1)

;; 4. Contractor submits first deliverable
(submit-phase-delivery u1 u0 "Wireframes completed - see link: https://...")

;; 5. Employer approves and 300 STX is automatically released
(approve-phase-delivery u1 u0)
```

## Error Codes

- `u100` - Admin only function
- `u101` - Agreement/phase not found
- `u102` - Already exists
- `u103` - Unauthorized access
- `u104` - Wrong status for operation
- `u105` - Insufficient funds
- `u106` - Invalid percentage values

## Deployment Requirements

- Stacks blockchain compatible environment
- Clarity smart contract runtime
- STX tokens for agreement funding

## Benefits

**For Employers:**
- Payment protection until work is delivered
- Clear milestone tracking and accountability
- Dispute resolution safety net

**For Contractors:**
- Guaranteed payment upon delivery
- Protected against payment delays
- Clear scope definition through phases

**For Arbitrators:**
- Earn fees for dispute resolution services
- Full case context and evidence available on-chain