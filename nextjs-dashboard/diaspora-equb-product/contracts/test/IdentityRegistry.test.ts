import { expect } from 'chai';
import { ethers } from 'hardhat';
import { IdentityRegistry } from '../typechain-types';
import { SignerWithAddress } from '@nomicfoundation/hardhat-ethers/signers';

describe('IdentityRegistry', () => {
  let registry: IdentityRegistry;
  let owner: SignerWithAddress;
  let user1: SignerWithAddress;
  let user2: SignerWithAddress;

  const hash1 = ethers.keccak256(ethers.toUtf8Bytes('identity-1'));
  const hash2 = ethers.keccak256(ethers.toUtf8Bytes('identity-2'));
  const zeroHash = ethers.ZeroHash;

  beforeEach(async () => {
    [owner, user1, user2] = await ethers.getSigners();
    const Factory = await ethers.getContractFactory('IdentityRegistry');
    registry = await Factory.deploy();
    await registry.waitForDeployment();
  });

  describe('bindIdentity', () => {
    it('should bind a wallet to an identity hash', async () => {
      await expect(registry.bindIdentity(user1.address, hash1))
        .to.emit(registry, 'IdentityBound')
        .withArgs(user1.address, hash1);

      expect(await registry.identityOf(user1.address)).to.equal(hash1);
      expect(await registry.walletOf(hash1)).to.equal(user1.address);
    });

    it('should revert if wallet is zero address', async () => {
      await expect(
        registry.bindIdentity(ethers.ZeroAddress, hash1),
      ).to.be.revertedWith('invalid wallet');
    });

    it('should revert if identity hash is zero', async () => {
      await expect(
        registry.bindIdentity(user1.address, zeroHash),
      ).to.be.revertedWith('invalid hash');
    });

    it('should revert if wallet is already bound', async () => {
      await registry.bindIdentity(user1.address, hash1);
      await expect(
        registry.bindIdentity(user1.address, hash2),
      ).to.be.revertedWith('wallet already bound');
    });

    it('should revert if identity hash is already bound', async () => {
      await registry.bindIdentity(user1.address, hash1);
      await expect(
        registry.bindIdentity(user2.address, hash1),
      ).to.be.revertedWith('hash already bound');
    });
  });

  describe('identityOf', () => {
    it('should return zero for unbound wallet', async () => {
      expect(await registry.identityOf(user1.address)).to.equal(zeroHash);
    });

    it('should return identity hash for bound wallet', async () => {
      await registry.bindIdentity(user1.address, hash1);
      expect(await registry.identityOf(user1.address)).to.equal(hash1);
    });
  });

  describe('walletOf', () => {
    it('should return zero address for unbound hash', async () => {
      expect(await registry.walletOf(hash1)).to.equal(ethers.ZeroAddress);
    });

    it('should return wallet for bound hash', async () => {
      await registry.bindIdentity(user1.address, hash1);
      expect(await registry.walletOf(hash1)).to.equal(user1.address);
    });
  });
});
