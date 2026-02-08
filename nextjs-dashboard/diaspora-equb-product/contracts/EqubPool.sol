// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./PayoutStream.sol";
import "./CollateralVault.sol";
import "./CreditRegistry.sol";
import "./IdentityRegistry.sol";
import "./TierRegistry.sol";

contract EqubPool {
    struct Pool {
        uint8 tier;
        uint256 contributionAmount;
        uint256 maxMembers;
        uint256 currentRound;
        address[] members;
        mapping(address => bool) isMember;
        mapping(address => bool) hasReceivedPayout;
    }

    PayoutStream public payoutStream;
    CollateralVault public collateralVault;
    CreditRegistry public creditRegistry;
    IdentityRegistry public identityRegistry;
    TierRegistry public tierRegistry;

    mapping(uint256 => Pool) private pools;
    uint256 public poolCount;

    event PoolCreated(uint256 indexed poolId, uint256 contributionAmount, uint256 maxMembers);
    event JoinedPool(uint256 indexed poolId, address indexed member);
    event ContributionReceived(uint256 indexed poolId, address indexed member, uint256 round);
    event DefaultTriggered(uint256 indexed poolId, address indexed member, uint256 round);
    event PayoutStreamScheduled(uint256 indexed poolId, address indexed beneficiary, uint256 total, uint256 rounds);

    constructor(
        PayoutStream _payoutStream,
        CollateralVault _collateralVault,
        CreditRegistry _creditRegistry,
        IdentityRegistry _identityRegistry,
        TierRegistry _tierRegistry
    ) {
        payoutStream = _payoutStream;
        collateralVault = _collateralVault;
        creditRegistry = _creditRegistry;
        identityRegistry = _identityRegistry;
        tierRegistry = _tierRegistry;
    }

    function createPool(
        uint8 tier,
        uint256 contributionAmount,
        uint256 maxMembers
    ) external returns (uint256) {
        require(contributionAmount > 0, "invalid contribution");
        require(maxMembers > 1, "invalid members");
        TierRegistry.TierConfig memory config = tierRegistry.tierConfig(tier);
        require(config.enabled, "tier disabled");
        require(contributionAmount <= config.maxPoolSize, "pool size exceeds tier");

        poolCount += 1;
        Pool storage pool = pools[poolCount];
        pool.tier = tier;
        pool.contributionAmount = contributionAmount;
        pool.maxMembers = maxMembers;
        pool.currentRound = 1;

        emit PoolCreated(poolCount, contributionAmount, maxMembers);
        return poolCount;
    }

    function joinPool(uint256 poolId) external {
        Pool storage pool = pools[poolId];
        require(pool.members.length < pool.maxMembers, "pool full");
        require(!pool.isMember[msg.sender], "already member");
        require(identityRegistry.identityOf(msg.sender) != bytes32(0), "identity not bound");

        pool.members.push(msg.sender);
        pool.isMember[msg.sender] = true;

        emit JoinedPool(poolId, msg.sender);
    }

    function contribute(uint256 poolId) external payable {
        Pool storage pool = pools[poolId];
        require(pool.isMember[msg.sender], "not member");
        require(msg.value == pool.contributionAmount, "invalid amount");

        emit ContributionReceived(poolId, msg.sender, pool.currentRound);
    }

    function triggerDefault(uint256 poolId, address member) external {
        Pool storage pool = pools[poolId];
        require(pool.isMember[member], "not member");

        payoutStream.freezeRemaining(poolId, member);
        collateralVault.slashCollateral(member, pool.contributionAmount);
        creditRegistry.updateScore(member, -10);

        emit DefaultTriggered(poolId, member, pool.currentRound);
    }

    function schedulePayoutStream(
        uint256 poolId,
        address beneficiary,
        uint256 total,
        uint256 upfrontPercent,
        uint256 totalRounds
    ) external {
        Pool storage pool = pools[poolId];
        require(pool.isMember[beneficiary], "not member");
        payoutStream.createStream(poolId, beneficiary, total, upfrontPercent, totalRounds);
        emit PayoutStreamScheduled(poolId, beneficiary, total, totalRounds);
    }
}
