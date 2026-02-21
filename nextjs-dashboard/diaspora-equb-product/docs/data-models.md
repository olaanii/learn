# Data Models (MVP)

## Identity
- identityHash: bytes32
- walletAddress: address
- boundAt: timestamp

## Pool
- poolId: uint256
- tier: uint8
- contributionAmount: uint256
- maxMembers: uint16
- currentRound: uint16
- treasury: address
- members: address[]
- contributedInRound: mapping(uint256 => mapping(address => bool))

## Tier Config
- tier: uint8
- maxPoolSize: uint256
- collateralRateBps: uint256
- enabled: bool

## Payout Stream
- poolId: uint256
- beneficiary: address
- total: uint256
- upfrontPercent: uint8
- roundAmount: uint256
- totalRounds: uint256
- releasedRounds: uint256
- released: uint256
- frozen: bool

## Collateral
- walletAddress: address
- lockedAmount: uint256
- slashedAmount: uint256
- availableBalance: uint256

## Credit Score
- walletAddress: address
- score: int256
- lastUpdated: timestamp
