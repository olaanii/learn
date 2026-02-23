import { expect } from 'chai';
import { ethers } from 'hardhat';
import { PayoutStream } from '../typechain-types';
import { SignerWithAddress } from '@nomicfoundation/hardhat-ethers/signers';

describe('PayoutStream', () => {
  let stream: PayoutStream;
  let owner: SignerWithAddress;
  let beneficiary: SignerWithAddress;
  let attacker: SignerWithAddress;

  const POOL_ID = 1;
  const TOTAL = ethers.parseEther('100');
  const UPFRONT_PERCENT = 20;
  const TOTAL_ROUNDS = 8;

  beforeEach(async () => {
    [owner, beneficiary, attacker] = await ethers.getSigners();
    const Factory = await ethers.getContractFactory('PayoutStream');
    stream = await Factory.deploy();
    await stream.waitForDeployment();
    await stream.setEqubPool(owner.address);
  });

  describe('access control', () => {
    it('should allow only owner to set equb pool', async () => {
      const anotherPool = beneficiary.address;
      const fresh = await (await ethers.getContractFactory('PayoutStream')).deploy();
      await fresh.waitForDeployment();

      await expect(
        fresh.connect(attacker).setEqubPool(anotherPool),
      ).to.be.revertedWith('only owner');

      await expect(fresh.setEqubPool(owner.address))
        .to.emit(fresh, 'EqubPoolSet')
        .withArgs(owner.address);
    });

    it('should block non-equbPool from mutating streams', async () => {
      await expect(
        stream.connect(attacker).createStream(POOL_ID, beneficiary.address, TOTAL, UPFRONT_PERCENT, TOTAL_ROUNDS),
      ).to.be.revertedWith('only equb pool');

      await stream.createStream(POOL_ID, beneficiary.address, TOTAL, UPFRONT_PERCENT, TOTAL_ROUNDS);

      await expect(
        stream.connect(attacker).releaseRound(POOL_ID, beneficiary.address),
      ).to.be.revertedWith('only equb pool');

      await expect(
        stream.connect(attacker).freezeRemaining(POOL_ID, beneficiary.address),
      ).to.be.revertedWith('only equb pool');
    });
  });

  describe('createStream', () => {
    it('should create a stream with correct parameters', async () => {
      await stream.createStream(POOL_ID, beneficiary.address, TOTAL, UPFRONT_PERCENT, TOTAL_ROUNDS);

      const details = await stream.streamDetails(POOL_ID, beneficiary.address);
      expect(details.total).to.equal(TOTAL);
      expect(details.upfrontPercent).to.equal(UPFRONT_PERCENT);
      expect(details.totalRounds).to.equal(TOTAL_ROUNDS);
      expect(details.frozen).to.equal(false);

      // Upfront = 100 * 20% = 20 ETH
      const expectedUpfront = ethers.parseEther('20');
      expect(details.released).to.equal(expectedUpfront);

      // Remaining = 80 ETH / 8 rounds = 10 ETH per round
      const expectedRoundAmount = ethers.parseEther('10');
      expect(details.roundAmount).to.equal(expectedRoundAmount);
    });

    it('should revert if upfront percent exceeds 30', async () => {
      await expect(
        stream.createStream(POOL_ID, beneficiary.address, TOTAL, 31, TOTAL_ROUNDS),
      ).to.be.revertedWith('upfront too high');
    });

    it('should accept upfront of exactly 30%', async () => {
      await stream.createStream(POOL_ID, beneficiary.address, TOTAL, 30, TOTAL_ROUNDS);
      const details = await stream.streamDetails(POOL_ID, beneficiary.address);
      expect(details.upfrontPercent).to.equal(30);
    });

    it('should revert if totalRounds is 0', async () => {
      await expect(
        stream.createStream(POOL_ID, beneficiary.address, TOTAL, UPFRONT_PERCENT, 0),
      ).to.be.revertedWith('invalid rounds');
    });
  });

  describe('releaseRound', () => {
    beforeEach(async () => {
      await stream.createStream(POOL_ID, beneficiary.address, TOTAL, UPFRONT_PERCENT, TOTAL_ROUNDS);
    });

    it('should release one round correctly', async () => {
      await expect(stream.releaseRound(POOL_ID, beneficiary.address))
        .to.emit(stream, 'RoundReleased')
        .withArgs(POOL_ID, beneficiary.address, ethers.parseEther('10'));

      const details = await stream.streamDetails(POOL_ID, beneficiary.address);
      expect(details.releasedRounds).to.equal(1);
      expect(details.released).to.equal(ethers.parseEther('30')); // 20 upfront + 10 round
    });

    it('should release all rounds', async () => {
      for (let i = 0; i < Number(TOTAL_ROUNDS); i++) {
        await stream.releaseRound(POOL_ID, beneficiary.address);
      }

      const details = await stream.streamDetails(POOL_ID, beneficiary.address);
      expect(details.releasedRounds).to.equal(TOTAL_ROUNDS);
      expect(details.released).to.equal(TOTAL);
    });

    it('should revert after all rounds released', async () => {
      for (let i = 0; i < Number(TOTAL_ROUNDS); i++) {
        await stream.releaseRound(POOL_ID, beneficiary.address);
      }

      await expect(
        stream.releaseRound(POOL_ID, beneficiary.address),
      ).to.be.revertedWith('all rounds released');
    });
  });

  describe('freezeRemaining', () => {
    beforeEach(async () => {
      await stream.createStream(POOL_ID, beneficiary.address, TOTAL, UPFRONT_PERCENT, TOTAL_ROUNDS);
    });

    it('should freeze a stream', async () => {
      await expect(stream.freezeRemaining(POOL_ID, beneficiary.address))
        .to.emit(stream, 'StreamFrozen')
        .withArgs(POOL_ID, beneficiary.address);

      const details = await stream.streamDetails(POOL_ID, beneficiary.address);
      expect(details.frozen).to.equal(true);
    });

    it('should prevent further releases after freeze', async () => {
      await stream.freezeRemaining(POOL_ID, beneficiary.address);
      await expect(
        stream.releaseRound(POOL_ID, beneficiary.address),
      ).to.be.revertedWith('stream frozen');
    });
  });
});
