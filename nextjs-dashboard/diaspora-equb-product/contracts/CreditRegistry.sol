// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract CreditRegistry {
    mapping(address => int256) private scores;

    event ScoreUpdated(address indexed user, int256 newScore, int256 delta);

    function updateScore(address user, int256 delta) external {
        scores[user] += delta;
        emit ScoreUpdated(user, scores[user], delta);
    }

    function scoreOf(address user) external view returns (int256) {
        return scores[user];
    }
}
