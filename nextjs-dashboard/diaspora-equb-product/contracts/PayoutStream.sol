// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract PayoutStream {
    struct Stream {
        uint256 total;
        uint256 upfrontPercent;
        uint256 released;
        bool frozen;
    }

    mapping(uint256 => mapping(address => Stream)) private streams;

    event StreamCreated(uint256 indexed poolId, address indexed beneficiary, uint256 total, uint256 upfrontPercent);
    event RoundReleased(uint256 indexed poolId, address indexed beneficiary, uint256 amount);
    event StreamFrozen(uint256 indexed poolId, address indexed beneficiary);

    function createStream(
        uint256 poolId,
        address beneficiary,
        uint256 total,
        uint256 upfrontPercent
    ) external {
        require(upfrontPercent <= 30, "upfront too high");
        streams[poolId][beneficiary] = Stream({
            total: total,
            upfrontPercent: upfrontPercent,
            released: (total * upfrontPercent) / 100,
            frozen: false
        });
        emit StreamCreated(poolId, beneficiary, total, upfrontPercent);
    }

    function releaseRound(uint256 poolId, address beneficiary, uint256 amount) external {
        Stream storage stream = streams[poolId][beneficiary];
        require(!stream.frozen, "stream frozen");
        require(stream.released + amount <= stream.total, "over release");
        stream.released += amount;
        emit RoundReleased(poolId, beneficiary, amount);
    }

    function freezeRemaining(uint256 poolId, address beneficiary) external {
        Stream storage stream = streams[poolId][beneficiary];
        stream.frozen = true;
        emit StreamFrozen(poolId, beneficiary);
    }
}
