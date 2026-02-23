// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract PayoutStream {
    address public owner;
    address public equbPool;

    struct Stream {
        uint256 total;
        uint256 upfrontPercent;
        uint256 roundAmount;
        uint256 totalRounds;
        uint256 releasedRounds;
        uint256 released;
        bool frozen;
    }

    mapping(uint256 => mapping(address => Stream)) private streams;

    event StreamCreated(
        uint256 indexed poolId,
        address indexed beneficiary,
        uint256 total,
        uint256 upfrontPercent,
        uint256 roundAmount,
        uint256 totalRounds
    );
    event RoundReleased(uint256 indexed poolId, address indexed beneficiary, uint256 amount);
    event StreamFrozen(uint256 indexed poolId, address indexed beneficiary);
    event EqubPoolSet(address indexed equbPoolAddress);

    modifier onlyOwner() {
        require(msg.sender == owner, "only owner");
        _;
    }

    modifier onlyEqubPool() {
        require(msg.sender == equbPool, "only equb pool");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function setEqubPool(address equbPoolAddress) external onlyOwner {
        require(equbPoolAddress != address(0), "invalid equb pool");
        require(equbPool == address(0), "equb pool already set");
        equbPool = equbPoolAddress;
        emit EqubPoolSet(equbPoolAddress);
    }

    function createStream(
        uint256 poolId,
        address beneficiary,
        uint256 total,
        uint256 upfrontPercent,
        uint256 totalRounds
    ) external onlyEqubPool {
        require(upfrontPercent <= 30, "upfront too high");
        require(totalRounds > 0, "invalid rounds");
        uint256 upfront = (total * upfrontPercent) / 100;
        uint256 remaining = total - upfront;
        uint256 roundAmount = remaining / totalRounds;
        streams[poolId][beneficiary] = Stream({
            total: total,
            upfrontPercent: upfrontPercent,
            roundAmount: roundAmount,
            totalRounds: totalRounds,
            releasedRounds: 0,
            released: upfront,
            frozen: false
        });
        emit StreamCreated(poolId, beneficiary, total, upfrontPercent, roundAmount, totalRounds);
    }

    function releaseRound(uint256 poolId, address beneficiary) external onlyEqubPool {
        Stream storage stream = streams[poolId][beneficiary];
        require(!stream.frozen, "stream frozen");
        require(stream.releasedRounds < stream.totalRounds, "all rounds released");
        uint256 amount = stream.roundAmount;
        require(stream.released + amount <= stream.total, "over release");
        stream.released += amount;
        stream.releasedRounds += 1;
        emit RoundReleased(poolId, beneficiary, amount);
    }

    function freezeRemaining(uint256 poolId, address beneficiary) external onlyEqubPool {
        Stream storage stream = streams[poolId][beneficiary];
        stream.frozen = true;
        emit StreamFrozen(poolId, beneficiary);
    }

    function streamDetails(uint256 poolId, address beneficiary) external view returns (Stream memory) {
        return streams[poolId][beneficiary];
    }
}
