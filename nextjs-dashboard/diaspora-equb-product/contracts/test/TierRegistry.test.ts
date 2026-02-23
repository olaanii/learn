import { expect } from 'chai';
import { ethers } from 'hardhat';
import { TierRegistry } from '../typechain-types';
import { SignerWithAddress } from '@nomicfoundation/hardhat-ethers/signers';

describe('TierRegistry', () => {
  let registry: TierRegistry;
  let owner: SignerWithAddress;
  let other: SignerWithAddress;

  beforeEach(async () => {
    [owner, other] = await ethers.getSigners();
    const Factory = await ethers.getContractFactory('TierRegistry');
    registry = await Factory.deploy();
    await registry.waitForDeployment();
  });

  describe('access control', () => {
    it('should allow only owner to configure tier', async () => {
      await expect(
        registry.connect(other).configureTier(0, ethers.parseEther('10'), 500, true),
      ).to.be.revertedWith('only owner');
    });
  });

  describe('configureTier', () => {
    it('should configure a tier with correct values', async () => {
      const maxPoolSize = ethers.parseEther('10');
      const collateralRateBps = 500; // 5%

      await expect(registry.configureTier(0, maxPoolSize, collateralRateBps, true))
        .to.emit(registry, 'TierConfigured')
        .withArgs(0, maxPoolSize, collateralRateBps, true);

      const config = await registry.tierConfig(0);
      expect(config.maxPoolSize).to.equal(maxPoolSize);
      expect(config.collateralRateBps).to.equal(collateralRateBps);
      expect(config.enabled).to.equal(true);
    });

    it('should allow updating an existing tier', async () => {
      await registry.configureTier(1, ethers.parseEther('50'), 1000, true);
      await registry.configureTier(1, ethers.parseEther('100'), 750, true);

      const config = await registry.tierConfig(1);
      expect(config.maxPoolSize).to.equal(ethers.parseEther('100'));
      expect(config.collateralRateBps).to.equal(750);
    });

    it('should allow disabling a tier', async () => {
      await registry.configureTier(2, ethers.parseEther('100'), 500, true);
      await registry.configureTier(2, ethers.parseEther('100'), 500, false);

      const config = await registry.tierConfig(2);
      expect(config.enabled).to.equal(false);
    });
  });

  describe('tierConfig', () => {
    it('should return default values for unconfigured tier', async () => {
      const config = await registry.tierConfig(99);
      expect(config.maxPoolSize).to.equal(0);
      expect(config.collateralRateBps).to.equal(0);
      expect(config.enabled).to.equal(false);
    });

    it('should configure all four tiers', async () => {
      // Tier 0: Small, no collateral
      await registry.configureTier(0, ethers.parseEther('1'), 0, true);
      // Tier 1: Medium, partial collateral
      await registry.configureTier(1, ethers.parseEther('10'), 1000, true);
      // Tier 2: Large, reduced collateral
      await registry.configureTier(2, ethers.parseEther('50'), 500, true);
      // Tier 3: Very large, minimal collateral
      await registry.configureTier(3, ethers.parseEther('200'), 200, true);

      const t0 = await registry.tierConfig(0);
      const t3 = await registry.tierConfig(3);

      expect(t0.collateralRateBps).to.equal(0);
      expect(t3.maxPoolSize).to.equal(ethers.parseEther('200'));
    });
  });
});
