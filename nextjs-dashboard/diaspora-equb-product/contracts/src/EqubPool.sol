// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./PayoutStream.sol";
import "./CollateralVault.sol";
import "./CreditRegistry.sol";
import "./IdentityRegistry.sol";
import "./TierRegistry.sol";
import "./IERC20.sol";

/**
 * @title EqubPool
 * @notice Core rotating-savings pool contract for Diaspora Equb.
 *
 * v2 Changes:
 *  - Pools can now accept an ERC-20 token (e.g. USDC/USDT) for contributions.
 *  - If `token` is address(0), the pool uses native CTC (backward compatible).
 *  - For ERC-20 pools, users must `approve()` this contract before calling `contribute()`.
 *  - A new `approveToken()` helper builds the approve TX for the frontend.
 */
contract EqubPool {
    struct Pool {
        uint8 tier;
        uint256 contributionAmount;
        uint256 maxMembers;
        uint256 currentRound;
        uint256 lastClosedRound;
        uint256 currentSeason;
        address creator;
        address treasury;
        address token; // address(0) = native CTC; otherwise ERC-20 address
        address[] members;
        mapping(address => bool) isMember;
        mapping(address => bool) isFrozenMember;
        mapping(uint256 => address) winnerForRound;
        mapping(uint256 => bool) winnerScheduledForRound;
        mapping(uint256 => mapping(address => bool)) hasWonInSeason;
        mapping(uint256 => mapping(address => bool)) contributedInRound;
    }

    PayoutStream public payoutStream;
    CollateralVault public collateralVault;
    CreditRegistry public creditRegistry;
    IdentityRegistry public identityRegistry;
    TierRegistry public tierRegistry;

    mapping(uint256 => Pool) private pools;
    uint256 public poolCount;

    modifier onlyPoolCreator(uint256 poolId) {
        require(pools[poolId].creator != address(0), "pool not found");
        require(pools[poolId].creator == msg.sender, "only creator");
        _;
    }

    // ─── Events ───────────────────────────────────────────────────────────────

    event PoolCreated(
        uint256 indexed poolId,
        uint256 contributionAmount,
        uint256 maxMembers,
        address token
    );
    event JoinedPool(uint256 indexed poolId, address indexed member);
    event ContributionReceived(
        uint256 indexed poolId,
        address indexed member,
        uint256 round
    );
    event DefaultTriggered(
        uint256 indexed poolId,
        address indexed member,
        uint256 round
    );
    event PayoutStreamScheduled(
        uint256 indexed poolId,
        address indexed beneficiary,
        uint256 total,
        uint256 rounds
    );
    event RoundClosed(uint256 indexed poolId, uint256 round);
    event RoundWinnerSelected(
        uint256 indexed poolId,
        uint256 indexed round,
        address indexed winner
    );
    event CollateralLocked(
        uint256 indexed poolId,
        address indexed member,
        uint256 amount
    );
    event PoolCompensated(
        uint256 indexed poolId,
        address indexed member,
        uint256 amount
    );

    // ─── Constructor ──────────────────────────────────────────────────────────

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

    // ─── Pool Lifecycle ───────────────────────────────────────────────────────

    /**
     * @notice Create a new Equb pool with an ERC-20 token for contributions.
     * @param tier       Tier level (0-3), determines collateral requirements.
     * @param contributionAmount  Amount each member contributes per round.
     * @param maxMembers Maximum number of pool members.
     * @param treasury   Address that receives pool funds.
     * @param token      ERC-20 token address for contributions, or address(0) for native CTC.
     */
    function createPool(
        uint8 tier,
        uint256 contributionAmount,
        uint256 maxMembers,
        address treasury,
        address token
    ) external returns (uint256) {
        return _createPool(tier, contributionAmount, maxMembers, treasury, token);
    }

    /**
     * @notice Legacy createPool without token parameter (uses native CTC).
     *         Kept for backward compatibility with existing callers.
     */
    function createPool(
        uint8 tier,
        uint256 contributionAmount,
        uint256 maxMembers,
        address treasury
    ) external returns (uint256) {
        return _createPool(tier, contributionAmount, maxMembers, treasury, address(0));
    }

    function _createPool(
        uint8 tier,
        uint256 contributionAmount,
        uint256 maxMembers,
        address treasury,
        address token
    ) internal returns (uint256) {
        require(contributionAmount > 0, "invalid contribution");
        require(maxMembers > 1, "invalid members");
        require(treasury != address(0), "invalid treasury");
        TierRegistry.TierConfig memory config = tierRegistry.tierConfig(tier);
        require(config.enabled, "tier disabled");
        require(contributionAmount <= config.maxPoolSize, "pool size exceeds tier");

        poolCount += 1;
        Pool storage pool = pools[poolCount];
        pool.tier = tier;
        pool.contributionAmount = contributionAmount;
        pool.maxMembers = maxMembers;
        pool.currentRound = 1;
        pool.lastClosedRound = 0;
        pool.currentSeason = 1;
        pool.creator = msg.sender;
        pool.treasury = treasury;
        pool.token = token;

        emit PoolCreated(poolCount, contributionAmount, maxMembers, token);
        return poolCount;
    }

    function joinPool(uint256 poolId) external {
        Pool storage pool = pools[poolId];
        require(pool.members.length < pool.maxMembers, "pool full");
        require(!pool.isMember[msg.sender], "already member");
        require(
            identityRegistry.identityOf(msg.sender) != bytes32(0),
            "identity not bound"
        );

        pool.members.push(msg.sender);
        pool.isMember[msg.sender] = true;

        emit JoinedPool(poolId, msg.sender);
    }

    /**
     * @notice Contribute to the current round of a pool.
     *
     * For native CTC pools:  send exact `contributionAmount` as msg.value.
     * For ERC-20 pools:      call `approve(equbPoolAddress, amount)` on the token first,
     *                         then call this function with msg.value = 0.
     */
    function contribute(uint256 poolId) external payable {
        Pool storage pool = pools[poolId];
        require(pool.isMember[msg.sender], "not member");
        require(
            !pool.contributedInRound[pool.currentRound][msg.sender],
            "already contributed"
        );

        if (pool.token == address(0)) {
            // Native CTC contribution
            require(msg.value == pool.contributionAmount, "invalid amount");
        } else {
            // ERC-20 contribution
            require(msg.value == 0, "do not send CTC for token pool");
            IERC20 token = IERC20(pool.token);
            require(
                token.allowance(msg.sender, address(this)) >=
                    pool.contributionAmount,
                "insufficient token allowance"
            );
            bool success = token.transferFrom(
                msg.sender,
                address(this),
                pool.contributionAmount
            );
            require(success, "token transfer failed");
        }

        pool.contributedInRound[pool.currentRound][msg.sender] = true;
        emit ContributionReceived(poolId, msg.sender, pool.currentRound);
    }

    function triggerDefault(uint256 poolId, address member) external onlyPoolCreator(poolId) {
        Pool storage pool = pools[poolId];
        require(pool.isMember[member], "not member");

        pool.isFrozenMember[member] = true;
        payoutStream.freezeRemaining(poolId, member);
        collateralVault.compensatePool(
            pool.treasury,
            member,
            pool.contributionAmount
        );
        creditRegistry.updateScore(member, -10);

        emit DefaultTriggered(poolId, member, pool.currentRound);
        emit PoolCompensated(poolId, member, pool.contributionAmount);
    }

    function closeRound(uint256 poolId) external onlyPoolCreator(poolId) {
        Pool storage pool = pools[poolId];
        uint256 memberCount = pool.members.length;
        for (uint256 i = 0; i < memberCount; i++) {
            address member = pool.members[i];
            if (
                !pool.contributedInRound[pool.currentRound][member]
            ) {
                pool.isFrozenMember[member] = true;
                payoutStream.freezeRemaining(poolId, member);
                collateralVault.compensatePool(
                    pool.treasury,
                    member,
                    pool.contributionAmount
                );
                creditRegistry.updateScore(member, -10);
                emit DefaultTriggered(poolId, member, pool.currentRound);
                emit PoolCompensated(poolId, member, pool.contributionAmount);
            } else {
                creditRegistry.updateScore(member, 1);
            }
        }

        uint256 closingRound = pool.currentRound;
        address winner = _pickSeasonWinner(pool, poolId, closingRound);
        pool.winnerForRound[closingRound] = winner;

        emit RoundWinnerSelected(poolId, closingRound, winner);
        emit RoundClosed(poolId, closingRound);
        pool.lastClosedRound = closingRound;
        pool.currentRound += 1;
    }

    // ─── View Functions ───────────────────────────────────────────────────────

    function hasContributed(
        uint256 poolId,
        uint256 round,
        address member
    ) external view returns (bool) {
        Pool storage pool = pools[poolId];
        return pool.contributedInRound[round][member];
    }

    /**
     * @notice Get the ERC-20 token address for a pool.
     *         Returns address(0) if the pool uses native CTC.
     */
    function poolToken(uint256 poolId) external view returns (address) {
        return pools[poolId].token;
    }

    // ─── Payout & Collateral ──────────────────────────────────────────────────

    function schedulePayoutStream(
        uint256 poolId,
        address beneficiary,
        uint256 total,
        uint256 upfrontPercent,
        uint256 totalRounds
    ) external onlyPoolCreator(poolId) {
        Pool storage pool = pools[poolId];
        require(pool.lastClosedRound > 0, "no closed round");
        uint256 targetRound = pool.lastClosedRound;
        require(
            !pool.winnerScheduledForRound[targetRound],
            "winner already scheduled"
        );
        address expectedWinner = pool.winnerForRound[targetRound];
        require(expectedWinner != address(0), "no eligible winner");
        require(beneficiary == expectedWinner, "not rotating winner");
        require(pool.isMember[beneficiary], "not member");
        require(!pool.isFrozenMember[beneficiary], "member frozen");
        require(pool.contributedInRound[targetRound][beneficiary], "winner not contributed");

        payoutStream.createStream(
            poolId,
            beneficiary,
            total,
            upfrontPercent,
            totalRounds
        );
        pool.winnerScheduledForRound[targetRound] = true;

        emit PayoutStreamScheduled(poolId, beneficiary, total, totalRounds);
    }

    function rotatingWinnerForLastClosedRound(
        uint256 poolId
    ) external view returns (uint256 round, address winner) {
        Pool storage pool = pools[poolId];
        round = pool.lastClosedRound;
        if (round == 0) {
            return (0, address(0));
        }
        winner = pool.winnerForRound[round];
    }

    function poolCreator(uint256 poolId) external view returns (address) {
        return pools[poolId].creator;
    }

    function roundWinner(uint256 poolId, uint256 round) external view returns (address) {
        return pools[poolId].winnerForRound[round];
    }

    function winnerScheduled(uint256 poolId, uint256 round) external view returns (bool) {
        return pools[poolId].winnerScheduledForRound[round];
    }

    function currentSeason(uint256 poolId) external view returns (uint256) {
        return pools[poolId].currentSeason;
    }

    function currentRound(uint256 poolId) external view returns (uint256) {
        return pools[poolId].currentRound;
    }

    function _pickSeasonWinner(
        Pool storage pool,
        uint256 poolId,
        uint256 round
    ) internal returns (address) {
        uint256 season = pool.currentSeason;
        uint256 eligibleCount = _eligibleCount(pool, season, round);
        if (eligibleCount == 0) {
            season += 1;
            pool.currentSeason = season;
            eligibleCount = _eligibleCount(pool, season, round);
        }

        require(eligibleCount > 0, "no eligible winner");

        uint256 random = uint256(
            keccak256(
                abi.encodePacked(
                    block.prevrandao,
                    block.timestamp,
                    poolId,
                    round,
                    msg.sender
                )
            )
        );
        uint256 pick = random % eligibleCount;

        uint256 memberCount = pool.members.length;
        uint256 seen = 0;
        for (uint256 i = 0; i < memberCount; i++) {
            address candidate = pool.members[i];
            if (_isEligibleWinner(pool, season, round, candidate)) {
                if (seen == pick) {
                    pool.hasWonInSeason[season][candidate] = true;
                    return candidate;
                }
                seen += 1;
            }
        }

        return address(0);
    }

    function _eligibleCount(
        Pool storage pool,
        uint256 season,
        uint256 round
    ) internal view returns (uint256 count) {
        uint256 memberCount = pool.members.length;
        for (uint256 i = 0; i < memberCount; i++) {
            if (_isEligibleWinner(pool, season, round, pool.members[i])) {
                count += 1;
            }
        }
    }

    function _isEligibleWinner(
        Pool storage pool,
        uint256 season,
        uint256 round,
        address candidate
    ) internal view returns (bool) {
        return (
            pool.isMember[candidate] &&
            !pool.isFrozenMember[candidate] &&
            pool.contributedInRound[round][candidate] &&
            !pool.hasWonInSeason[season][candidate]
        );
    }

    function lockPartialCollateral(
        uint256 poolId,
        address member
    ) external {
        Pool storage pool = pools[poolId];
        require(pool.isMember[member], "not member");
        PayoutStream.Stream memory stream = payoutStream.streamDetails(
            poolId,
            member
        );
        uint256 remaining = stream.total - stream.released;
        TierRegistry.TierConfig memory config = tierRegistry.tierConfig(
            pool.tier
        );
        uint256 requiredCollateral = (remaining * config.collateralRateBps) /
            10000;
        collateralVault.lockCollateral(member, requiredCollateral);
        emit CollateralLocked(poolId, member, requiredCollateral);
    }
}
