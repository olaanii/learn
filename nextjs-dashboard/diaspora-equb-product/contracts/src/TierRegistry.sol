// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract TierRegistry {
    address public owner;

    struct TierConfig {
        uint256 maxPoolSize;
        uint256 collateralRateBps;
        bool enabled;
    }

    mapping(uint8 => TierConfig) private tiers;

    event TierConfigured(uint8 indexed tier, uint256 maxPoolSize, uint256 collateralRateBps, bool enabled);

    modifier onlyOwner() {
        require(msg.sender == owner, "only owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function configureTier(
        uint8 tier,
        uint256 maxPoolSize,
        uint256 collateralRateBps,
        bool enabled
    ) external onlyOwner {
        tiers[tier] = TierConfig({
            maxPoolSize: maxPoolSize,
            collateralRateBps: collateralRateBps,
            enabled: enabled
        });
        emit TierConfigured(tier, maxPoolSize, collateralRateBps, enabled);
    }

    function tierConfig(uint8 tier) external view returns (TierConfig memory) {
        return tiers[tier];
    }
}
