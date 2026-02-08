// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract TierRegistry {
    struct TierConfig {
        uint256 maxPoolSize;
        uint256 collateralRateBps;
        bool enabled;
    }

    mapping(uint8 => TierConfig) private tiers;

    event TierConfigured(uint8 indexed tier, uint256 maxPoolSize, uint256 collateralRateBps, bool enabled);

    function configureTier(
        uint8 tier,
        uint256 maxPoolSize,
        uint256 collateralRateBps,
        bool enabled
    ) external {
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
