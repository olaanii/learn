// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./PayoutStream.sol";
import "./CollateralVault.sol";
import "./CreditRegistry.sol";
import "./IdentityRegistry.sol";

contract EqubPool {
    struct Pool {
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

    mapping(uint256 => Pool) private pools;
    uint256 public poolCount;

    event PoolCreated(uint256 indexed poolId, uint256 contributionAmount, uint256 maxMembers);
    event JoinedPool(uint256 indexed poolId, address indexed member);
    event ContributionReceived(uint256 indexed poolId, address indexed member, uint256 round);
    event DefaultTriggered(uint256 indexed poolId, address indexed member, uint256 round);

    constructor(
        PayoutStream _payoutStream,
        CollateralVault _collateralVault,
        CreditRegistry _creditRegistry,
        IdentityRegistry _identityRegistry
    ) {
        payoutStream = _payoutStream;
        collateralVault = _collateralVault;
        creditRegistry = _creditRegistry;
        identityRegistry = _identityRegistry;
    }

    function createPool(uint256 contributionAmount, uint256 maxMembers) external returns (uint256) {
        require(contributionAmount > 0, "invalid contribution");
        require(maxMembers > 1, "invalid members");

        poolCount += 1;
        Pool storage pool = pools[poolCount];
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
}
