import { expect } from 'chai';
import { ethers } from 'hardhat';
import { CreditRegistry } from '../typechain-types';
import { SignerWithAddress } from '@nomicfoundation/hardhat-ethers/signers';

describe('CreditRegistry', () => {
  let registry: CreditRegistry;
  let owner: SignerWithAddress;
  let user1: SignerWithAddress;

  beforeEach(async () => {
    [owner, user1] = await ethers.getSigners();
    const Factory = await ethers.getContractFactory('CreditRegistry');
    registry = await Factory.deploy();
    await registry.waitForDeployment();
  });

  describe('updateScore', () => {
    it('should increase score with positive delta', async () => {
      await expect(registry.updateScore(user1.address, 10))
        .to.emit(registry, 'ScoreUpdated')
        .withArgs(user1.address, 10, 10);

      expect(await registry.scoreOf(user1.address)).to.equal(10);
    });

    it('should decrease score with negative delta', async () => {
      await registry.updateScore(user1.address, 50);
      await expect(registry.updateScore(user1.address, -30))
        .to.emit(registry, 'ScoreUpdated')
        .withArgs(user1.address, 20, -30);

      expect(await registry.scoreOf(user1.address)).to.equal(20);
    });

    it('should allow negative total score', async () => {
      await registry.updateScore(user1.address, -10);
      expect(await registry.scoreOf(user1.address)).to.equal(-10);
    });

    it('should accumulate over multiple updates', async () => {
      await registry.updateScore(user1.address, 5);
      await registry.updateScore(user1.address, 3);
      await registry.updateScore(user1.address, -2);
      expect(await registry.scoreOf(user1.address)).to.equal(6);
    });
  });

  describe('scoreOf', () => {
    it('should return 0 for unknown user', async () => {
      expect(await registry.scoreOf(user1.address)).to.equal(0);
    });
  });
});
