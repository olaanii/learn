import { expect } from 'chai';
import { ethers } from 'hardhat';
import { CollateralVault } from '../typechain-types';
import { SignerWithAddress } from '@nomicfoundation/hardhat-ethers/signers';

describe('CollateralVault', () => {
  let vault: CollateralVault;
  let owner: SignerWithAddress;
  let user1: SignerWithAddress;
  let treasury: SignerWithAddress;

  beforeEach(async () => {
    [owner, user1, treasury] = await ethers.getSigners();
    const Factory = await ethers.getContractFactory('CollateralVault');
    vault = await Factory.deploy();
    await vault.waitForDeployment();
  });

  describe('depositCollateral', () => {
    it('should accept deposits and track balance', async () => {
      const amount = ethers.parseEther('1');
      await expect(vault.connect(user1).depositCollateral({ value: amount }))
        .to.emit(vault, 'CollateralDeposited')
        .withArgs(user1.address, amount);

      expect(await vault.collateralOf(user1.address)).to.equal(amount);
    });

    it('should revert on zero deposit', async () => {
      await expect(
        vault.connect(user1).depositCollateral({ value: 0 }),
      ).to.be.revertedWith('invalid amount');
    });

    it('should accumulate multiple deposits', async () => {
      await vault.connect(user1).depositCollateral({ value: ethers.parseEther('1') });
      await vault.connect(user1).depositCollateral({ value: ethers.parseEther('2') });
      expect(await vault.collateralOf(user1.address)).to.equal(ethers.parseEther('3'));
    });
  });

  describe('lockCollateral', () => {
    it('should lock available collateral', async () => {
      await vault.connect(user1).depositCollateral({ value: ethers.parseEther('5') });
      await expect(vault.lockCollateral(user1.address, ethers.parseEther('3')))
        .to.emit(vault, 'CollateralLocked')
        .withArgs(user1.address, ethers.parseEther('3'));

      expect(await vault.collateralOf(user1.address)).to.equal(ethers.parseEther('2'));
      expect(await vault.lockedOf(user1.address)).to.equal(ethers.parseEther('3'));
    });

    it('should revert if insufficient collateral', async () => {
      await vault.connect(user1).depositCollateral({ value: ethers.parseEther('1') });
      await expect(
        vault.lockCollateral(user1.address, ethers.parseEther('5')),
      ).to.be.revertedWith('insufficient collateral');
    });
  });

  describe('slashCollateral', () => {
    it('should slash up to available balance', async () => {
      await vault.connect(user1).depositCollateral({ value: ethers.parseEther('3') });
      await expect(vault.slashCollateral(user1.address, ethers.parseEther('2')))
        .to.emit(vault, 'CollateralSlashed')
        .withArgs(user1.address, ethers.parseEther('2'));

      expect(await vault.collateralOf(user1.address)).to.equal(ethers.parseEther('1'));
    });

    it('should slash only available if amount exceeds balance', async () => {
      await vault.connect(user1).depositCollateral({ value: ethers.parseEther('1') });
      await vault.slashCollateral(user1.address, ethers.parseEther('5'));
      expect(await vault.collateralOf(user1.address)).to.equal(0);
    });
  });

  describe('slashLocked', () => {
    it('should slash locked collateral', async () => {
      await vault.connect(user1).depositCollateral({ value: ethers.parseEther('5') });
      await vault.lockCollateral(user1.address, ethers.parseEther('4'));
      await vault.slashLocked(user1.address, ethers.parseEther('2'));

      expect(await vault.lockedOf(user1.address)).to.equal(ethers.parseEther('2'));
    });
  });

  describe('compensatePool', () => {
    it('should compensate from locked balance', async () => {
      await vault.connect(user1).depositCollateral({ value: ethers.parseEther('5') });
      await vault.lockCollateral(user1.address, ethers.parseEther('4'));

      await expect(
        vault.compensatePool(treasury.address, user1.address, ethers.parseEther('3')),
      )
        .to.emit(vault, 'CollateralCompensated')
        .withArgs(treasury.address, user1.address, ethers.parseEther('3'));

      expect(await vault.lockedOf(user1.address)).to.equal(ethers.parseEther('1'));
    });

    it('should compensate only available locked if amount exceeds', async () => {
      await vault.connect(user1).depositCollateral({ value: ethers.parseEther('2') });
      await vault.lockCollateral(user1.address, ethers.parseEther('2'));

      await vault.compensatePool(treasury.address, user1.address, ethers.parseEther('10'));
      expect(await vault.lockedOf(user1.address)).to.equal(0);
    });
  });

  describe('releaseCollateral', () => {
    it('should release collateral back to user', async () => {
      await vault.connect(user1).depositCollateral({ value: ethers.parseEther('3') });

      const balanceBefore = await ethers.provider.getBalance(user1.address);
      await vault.releaseCollateral(user1.address, ethers.parseEther('2'));
      const balanceAfter = await ethers.provider.getBalance(user1.address);

      expect(balanceAfter - balanceBefore).to.equal(ethers.parseEther('2'));
      expect(await vault.collateralOf(user1.address)).to.equal(ethers.parseEther('1'));
    });

    it('should revert if insufficient collateral', async () => {
      await expect(
        vault.releaseCollateral(user1.address, ethers.parseEther('1')),
      ).to.be.revertedWith('insufficient collateral');
    });
  });
});
