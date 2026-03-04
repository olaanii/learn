import { expect } from 'chai';
import { ethers } from 'hardhat';
import { AchievementBadge } from '../typechain-types';
import { SignerWithAddress } from '@nomicfoundation/hardhat-ethers/signers';

describe('AchievementBadge', () => {
  let badge: AchievementBadge;
  let owner: SignerWithAddress;
  let minter: SignerWithAddress;
  let user1: SignerWithAddress;
  let user2: SignerWithAddress;

  beforeEach(async () => {
    [owner, minter, user1, user2] = await ethers.getSigners();

    const BadgeFactory = await ethers.getContractFactory('AchievementBadge');
    badge = await BadgeFactory.deploy();

    await badge.setMinter(minter.address);
  });

  describe('setMinter', () => {
    it('should allow owner to set minter', async () => {
      await expect(badge.setMinter(user1.address))
        .to.emit(badge, 'MinterUpdated')
        .withArgs(user1.address);

      expect(await badge.minter()).to.equal(user1.address);
    });

    it('should revert if non-owner tries to set minter', async () => {
      await expect(
        badge.connect(user1).setMinter(user2.address),
      ).to.be.revertedWith('only owner');
    });
  });

  describe('mint', () => {
    it('should mint a badge and emit events', async () => {
      const badgeType = 0;
      const uri = 'ipfs://badge/0';

      const tx = badge.connect(minter).mint(user1.address, badgeType, uri);

      await expect(tx)
        .to.emit(badge, 'BadgeMinted')
        .withArgs(user1.address, 1, badgeType, uri);

      await expect(tx)
        .to.emit(badge, 'Transfer')
        .withArgs(ethers.ZeroAddress, user1.address, 1);
    });

    it('should increment totalSupply', async () => {
      expect(await badge.totalSupply()).to.equal(0);

      await badge.connect(minter).mint(user1.address, 0, 'ipfs://0');
      expect(await badge.totalSupply()).to.equal(1);

      await badge.connect(minter).mint(user2.address, 0, 'ipfs://0');
      expect(await badge.totalSupply()).to.equal(2);
    });

    it('should revert if non-minter tries to mint', async () => {
      await expect(
        badge.connect(user1).mint(user1.address, 0, 'ipfs://0'),
      ).to.be.revertedWith('only minter');
    });

    it('should revert if user already has badge type', async () => {
      await badge.connect(minter).mint(user1.address, 0, 'ipfs://0');
      await expect(
        badge.connect(minter).mint(user1.address, 0, 'ipfs://0-dup'),
      ).to.be.revertedWith('already has badge type');
    });

    it('should allow same badge type for different users', async () => {
      await badge.connect(minter).mint(user1.address, 0, 'ipfs://0');
      await badge.connect(minter).mint(user2.address, 0, 'ipfs://0');
      expect(await badge.totalSupply()).to.equal(2);
    });

    it('should allow different badge types for same user', async () => {
      await badge.connect(minter).mint(user1.address, 0, 'ipfs://0');
      await badge.connect(minter).mint(user1.address, 1, 'ipfs://1');
      expect(await badge.balanceOf(user1.address)).to.equal(2);
    });
  });

  describe('view functions', () => {
    beforeEach(async () => {
      await badge.connect(minter).mint(user1.address, 0, 'ipfs://badge/first-equb');
      await badge.connect(minter).mint(user1.address, 4, 'ipfs://badge/zero-defaults');
      await badge.connect(minter).mint(user2.address, 7, 'ipfs://badge/pioneer');
    });

    it('ownerOf should return correct owner', async () => {
      expect(await badge.ownerOf(1)).to.equal(user1.address);
      expect(await badge.ownerOf(3)).to.equal(user2.address);
    });

    it('balanceOf should return correct count', async () => {
      expect(await badge.balanceOf(user1.address)).to.equal(2);
      expect(await badge.balanceOf(user2.address)).to.equal(1);
    });

    it('getBadge should return correct badge data', async () => {
      const b = await badge.getBadge(1);
      expect(b.badgeType).to.equal(0);
      expect(b.recipient).to.equal(user1.address);
      expect(b.metadataURI).to.equal('ipfs://badge/first-equb');
      expect(b.mintedAt).to.be.gt(0);
    });

    it('getBadgesOf should return all token IDs for owner', async () => {
      const ids = await badge.getBadgesOf(user1.address);
      expect(ids.length).to.equal(2);
      expect(ids[0]).to.equal(1);
      expect(ids[1]).to.equal(2);
    });

    it('hasBadgeType should return correct status', async () => {
      expect(await badge.hasBadgeType(user1.address, 0)).to.be.true;
      expect(await badge.hasBadgeType(user1.address, 4)).to.be.true;
      expect(await badge.hasBadgeType(user1.address, 7)).to.be.false;
      expect(await badge.hasBadgeType(user2.address, 7)).to.be.true;
    });

    it('tokenURI should return correct metadata URI', async () => {
      expect(await badge.tokenURI(1)).to.equal('ipfs://badge/first-equb');
      expect(await badge.tokenURI(2)).to.equal('ipfs://badge/zero-defaults');
    });
  });

  describe('soulbound (non-transferable)', () => {
    beforeEach(async () => {
      await badge.connect(minter).mint(user1.address, 0, 'ipfs://0');
    });

    it('should revert on transferFrom', async () => {
      await expect(
        badge.connect(user1)['transferFrom(address,address,uint256)'](user1.address, user2.address, 1),
      ).to.be.revertedWith('soulbound: non-transferable');
    });

    it('should revert on safeTransferFrom', async () => {
      await expect(
        badge.connect(user1)['safeTransferFrom(address,address,uint256)'](user1.address, user2.address, 1),
      ).to.be.revertedWith('soulbound: non-transferable');
    });
  });

  describe('supportsInterface', () => {
    it('should support ERC-721 interface', async () => {
      expect(await badge.supportsInterface('0x80ac58cd')).to.be.true;
    });

    it('should support ERC-165 interface', async () => {
      expect(await badge.supportsInterface('0x01ffc9a7')).to.be.true;
    });

    it('should not support random interface', async () => {
      expect(await badge.supportsInterface('0xdeadbeef')).to.be.false;
    });
  });
});
