// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./EqubPool.sol";

/**
 * @title EqubGovernor
 * @notice Lightweight per-equb governance for the Diaspora Equb platform.
 *         Pool creators propose rule changes; members vote; simple majority executes.
 */
contract EqubGovernor {
    struct Proposal {
        uint256 proposalId;
        uint256 equbId;
        address proposer;
        bytes32 ruleHash;
        EqubRules proposedRules;
        string description;
        uint256 yesVotes;
        uint256 noVotes;
        uint256 deadline;
        bool executed;
        bool cancelled;
    }

    EqubPool public equbPool;
    uint256 public proposalCount;
    uint256 public votingPeriod;
    uint256 public cooldownPeriod;

    mapping(uint256 => Proposal) private proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    /// @dev Last rejected-proposal timestamp per equb, used for cooldown enforcement
    mapping(uint256 => uint256) public lastRejectedTimestamp;

    // ─── Events ──────────────────────────────────────────────────────────────

    event ProposalCreated(
        uint256 indexed proposalId,
        uint256 indexed equbId,
        address indexed proposer,
        bytes32 ruleHash,
        string description,
        uint256 deadline
    );
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCancelled(uint256 indexed proposalId);

    // ─── Constructor ─────────────────────────────────────────────────────────

    constructor(EqubPool _equbPool) {
        equbPool = _equbPool;
        votingPeriod = 3 days;
        cooldownPeriod = 7 days;
    }

    // ─── Proposal Lifecycle ──────────────────────────────────────────────────

    function proposeRuleChange(
        uint256 equbId,
        EqubRules calldata newRules,
        string calldata description
    ) external returns (uint256) {
        require(equbPool.poolCreator(equbId) == msg.sender, "only pool creator");
        require(
            block.timestamp >= lastRejectedTimestamp[equbId] + cooldownPeriod,
            "cooldown active"
        );

        proposalCount += 1;
        Proposal storage p = proposals[proposalCount];
        p.proposalId = proposalCount;
        p.equbId = equbId;
        p.proposer = msg.sender;
        p.proposedRules = newRules;
        p.ruleHash = keccak256(abi.encode(newRules));
        p.description = description;
        p.deadline = block.timestamp + votingPeriod;

        emit ProposalCreated(
            proposalCount,
            equbId,
            msg.sender,
            p.ruleHash,
            description,
            p.deadline
        );

        return proposalCount;
    }

    function vote(uint256 proposalId, bool support) external {
        Proposal storage p = proposals[proposalId];
        require(p.proposer != address(0), "proposal not found");
        require(!p.executed, "already executed");
        require(!p.cancelled, "proposal cancelled");
        require(block.timestamp <= p.deadline, "voting ended");
        require(!hasVoted[proposalId][msg.sender], "already voted");
        require(equbPool.isMember(p.equbId, msg.sender), "not a member");

        hasVoted[proposalId][msg.sender] = true;

        if (support) {
            p.yesVotes += 1;
        } else {
            p.noVotes += 1;
        }

        emit VoteCast(proposalId, msg.sender, support);
    }

    function executeProposal(uint256 proposalId) external {
        Proposal storage p = proposals[proposalId];
        require(p.proposer != address(0), "proposal not found");
        require(!p.executed, "already executed");
        require(!p.cancelled, "proposal cancelled");
        require(block.timestamp > p.deadline, "voting not ended");
        require(p.yesVotes > p.noVotes, "majority not reached");

        p.executed = true;
        equbPool.updateRules(p.equbId, p.proposedRules);

        emit ProposalExecuted(proposalId);
    }

    function cancelProposal(uint256 proposalId) external {
        Proposal storage p = proposals[proposalId];
        require(p.proposer != address(0), "proposal not found");
        require(p.proposer == msg.sender, "only proposer");
        require(!p.executed, "already executed");
        require(block.timestamp <= p.deadline, "voting ended");

        p.cancelled = true;

        emit ProposalCancelled(proposalId);
    }

    // ─── View Functions ──────────────────────────────────────────────────────

    function getProposal(uint256 proposalId)
        external
        view
        returns (
            uint256 id,
            uint256 equbId,
            address proposer,
            bytes32 ruleHash,
            EqubRules memory proposedRules,
            string memory description,
            uint256 yesVotes,
            uint256 noVotes,
            uint256 deadline,
            bool executed,
            bool cancelled
        )
    {
        Proposal storage p = proposals[proposalId];
        return (
            p.proposalId,
            p.equbId,
            p.proposer,
            p.ruleHash,
            p.proposedRules,
            p.description,
            p.yesVotes,
            p.noVotes,
            p.deadline,
            p.executed,
            p.cancelled
        );
    }
}
