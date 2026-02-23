import { expect } from 'chai';
import { ethers } from 'hardhat';
import {
  EqubPool,
  PayoutStream,
  CollateralVault,
  CreditRegistry,
  IdentityRegistry,
  TierRegistry,
} from '../typechain-types';
import { SignerWithAddress } from '@nomicfoundation/hardhat-ethers/signers';

describe('EqubPool', () => {
  let equbPool: EqubPool;
  let payoutStream: PayoutStream;
  let collateralVault: CollateralVault;
  let creditRegistry: CreditRegistry;
  let identityRegistry: IdentityRegistry;
  let tierRegistry: TierRegistry;

  let owner: SignerWithAddress;
  let user1: SignerWithAddress;
  let user2: SignerWithAddress;
  let user3: SignerWithAddress;
  let treasury: SignerWithAddress;

  const CONTRIBUTION = ethers.parseEther('1');
  const MAX_MEMBERS = 5;
  const TIER = 0;

  beforeEach(async () => {
    [owner, user1, user2, user3, treasury] = await ethers.getSigners();

    // Deploy all dependency contracts
    const PayoutStreamFactory = await ethers.getContractFactory('PayoutStream');
    payoutStream = await PayoutStreamFactory.deploy();

    const CollateralVaultFactory = await ethers.getContractFactory('CollateralVault');
    collateralVault = await CollateralVaultFactory.deploy();

    const CreditRegistryFactory = await ethers.getContractFactory('CreditRegistry');
    creditRegistry = await CreditRegistryFactory.deploy();

    const IdentityRegistryFactory = await ethers.getContractFactory('IdentityRegistry');
    identityRegistry = await IdentityRegistryFactory.deploy();

    const TierRegistryFactory = await ethers.getContractFactory('TierRegistry');
    tierRegistry = await TierRegistryFactory.deploy();

    // Configure Tier 0
    await tierRegistry.configureTier(TIER, ethers.parseEther('100'), 0, true);

    // Deploy EqubPool with all dependencies
    const EqubPoolFactory = await ethers.getContractFactory('EqubPool');
    equbPool = await EqubPoolFactory.deploy(
      await payoutStream.getAddress(),
      await collateralVault.getAddress(),
      await creditRegistry.getAddress(),
      await identityRegistry.getAddress(),
      await tierRegistry.getAddress(),
    );

    await payoutStream.setEqubPool(await equbPool.getAddress());

    // Bind identities for users
    const hash1 = ethers.keccak256(ethers.toUtf8Bytes('user1'));
    const hash2 = ethers.keccak256(ethers.toUtf8Bytes('user2'));
    const hash3 = ethers.keccak256(ethers.toUtf8Bytes('user3'));

    await identityRegistry.bindIdentity(user1.address, hash1);
    await identityRegistry.bindIdentity(user2.address, hash2);
    await identityRegistry.bindIdentity(user3.address, hash3);
  });

  describe('createPool', () => {
    it('should create a pool and return pool ID', async () => {
      await expect(
        equbPool['createPool(uint8,uint256,uint256,address)'](TIER, CONTRIBUTION, MAX_MEMBERS, treasury.address),
      )
        .to.emit(equbPool, 'PoolCreated')
        .withArgs(1, CONTRIBUTION, MAX_MEMBERS, ethers.ZeroAddress);

      expect(await equbPool.poolCount()).to.equal(1);
    });

    it('should revert with zero contribution', async () => {
      await expect(
        equbPool['createPool(uint8,uint256,uint256,address)'](TIER, 0, MAX_MEMBERS, treasury.address),
      ).to.be.revertedWith('invalid contribution');
    });

    it('should revert with 1 member', async () => {
      await expect(
        equbPool['createPool(uint8,uint256,uint256,address)'](TIER, CONTRIBUTION, 1, treasury.address),
      ).to.be.revertedWith('invalid members');
    });

    it('should revert with zero treasury', async () => {
      await expect(
        equbPool['createPool(uint8,uint256,uint256,address)'](TIER, CONTRIBUTION, MAX_MEMBERS, ethers.ZeroAddress),
      ).to.be.revertedWith('invalid treasury');
    });

    it('should revert if tier is disabled', async () => {
      await tierRegistry.configureTier(1, ethers.parseEther('50'), 500, false);
      await expect(
        equbPool['createPool(uint8,uint256,uint256,address)'](1, CONTRIBUTION, MAX_MEMBERS, treasury.address),
      ).to.be.revertedWith('tier disabled');
    });

    it('should revert if contribution exceeds tier max pool size', async () => {
      await expect(
        equbPool['createPool(uint8,uint256,uint256,address)'](TIER, ethers.parseEther('200'), MAX_MEMBERS, treasury.address),
      ).to.be.revertedWith('pool size exceeds tier');
    });
  });

  describe('joinPool', () => {
    let poolId: number;

    beforeEach(async () => {
      await equbPool['createPool(uint8,uint256,uint256,address)'](TIER, CONTRIBUTION, MAX_MEMBERS, treasury.address);
      poolId = 1;
    });

    it('should allow an identified user to join', async () => {
      await expect(equbPool.connect(user1).joinPool(poolId))
        .to.emit(equbPool, 'JoinedPool')
        .withArgs(poolId, user1.address);
    });

    it('should revert if user has no identity', async () => {
      await expect(
        equbPool.connect(treasury).joinPool(poolId), // treasury has no identity bound
      ).to.be.revertedWith('identity not bound');
    });

    it('should revert if already a member', async () => {
      await equbPool.connect(user1).joinPool(poolId);
      await expect(
        equbPool.connect(user1).joinPool(poolId),
      ).to.be.revertedWith('already member');
    });
  });

  describe('contribute', () => {
    let poolId: number;

    beforeEach(async () => {
      await equbPool['createPool(uint8,uint256,uint256,address)'](TIER, CONTRIBUTION, MAX_MEMBERS, treasury.address);
      poolId = 1;
      await equbPool.connect(user1).joinPool(poolId);
      await equbPool.connect(user2).joinPool(poolId);
    });

    it('should accept a valid contribution', async () => {
      await expect(
        equbPool.connect(user1).contribute(poolId, { value: CONTRIBUTION }),
      )
        .to.emit(equbPool, 'ContributionReceived')
        .withArgs(poolId, user1.address, 1);
    });

    it('should revert if not a member', async () => {
      await expect(
        equbPool.connect(user3).contribute(poolId, { value: CONTRIBUTION }),
      ).to.be.revertedWith('not member');
    });

    it('should revert on wrong amount', async () => {
      await expect(
        equbPool.connect(user1).contribute(poolId, { value: ethers.parseEther('0.5') }),
      ).to.be.revertedWith('invalid amount');
    });

    it('should revert on double contribution in same round', async () => {
      await equbPool.connect(user1).contribute(poolId, { value: CONTRIBUTION });
      await expect(
        equbPool.connect(user1).contribute(poolId, { value: CONTRIBUTION }),
      ).to.be.revertedWith('already contributed');
    });

    it('should track contributions correctly', async () => {
      await equbPool.connect(user1).contribute(poolId, { value: CONTRIBUTION });
      expect(await equbPool.hasContributed(poolId, 1, user1.address)).to.be.true;
      expect(await equbPool.hasContributed(poolId, 1, user2.address)).to.be.false;
    });
  });

  describe('closeRound', () => {
    let poolId: number;

    beforeEach(async () => {
      await equbPool['createPool(uint8,uint256,uint256,address)'](TIER, CONTRIBUTION, MAX_MEMBERS, treasury.address);
      poolId = 1;
      await equbPool.connect(user1).joinPool(poolId);
      await equbPool.connect(user2).joinPool(poolId);
    });

    it('should reward contributors and penalize defaulters', async () => {
      // Only user1 contributes
      await equbPool.connect(user1).contribute(poolId, { value: CONTRIBUTION });

      // Close round -- user1 gets +1, user2 gets -10
      await expect(equbPool.closeRound(poolId))
        .to.emit(equbPool, 'RoundClosed')
        .withArgs(poolId, 1);

      // user1 rewarded
      expect(await creditRegistry.scoreOf(user1.address)).to.equal(1);
      // user2 penalized
      expect(await creditRegistry.scoreOf(user2.address)).to.equal(-10);
    });

    it('should allow only pool creator to close round', async () => {
      await expect(
        equbPool.connect(user1).closeRound(poolId),
      ).to.be.revertedWith('only creator');
    });
  });

  describe('schedulePayoutStream', () => {
    let poolId: number;

    beforeEach(async () => {
      await equbPool['createPool(uint8,uint256,uint256,address)'](TIER, CONTRIBUTION, MAX_MEMBERS, treasury.address);
      poolId = 1;
      await equbPool.connect(user1).joinPool(poolId);
      await equbPool.connect(user2).joinPool(poolId);

      await equbPool.connect(user1).contribute(poolId, { value: CONTRIBUTION });
      await equbPool.connect(user2).contribute(poolId, { value: CONTRIBUTION });
      await equbPool.closeRound(poolId);
    });

    it('should schedule a payout stream for the rotating winner', async () => {
      const total = ethers.parseEther('10');
      const upfrontPercent = 20;
      const totalRounds = 8;

      const [, winner] = await equbPool.rotatingWinnerForLastClosedRound(poolId);

      await expect(
        equbPool.schedulePayoutStream(poolId, winner, total, upfrontPercent, totalRounds),
      )
        .to.emit(equbPool, 'PayoutStreamScheduled')
        .withArgs(poolId, winner, total, totalRounds);

      const details = await payoutStream.streamDetails(poolId, winner);
      expect(details.total).to.equal(total);
    });

    it('should revert if beneficiary is not the current rotating winner', async () => {
      const [, winner] = await equbPool.rotatingWinnerForLastClosedRound(poolId);
      const wrongWinner =
        winner.toLowerCase() === user1.address.toLowerCase()
          ? user2.address
          : user1.address;
      await expect(
        equbPool.schedulePayoutStream(poolId, wrongWinner, ethers.parseEther('10'), 20, 8),
      ).to.be.revertedWith('not rotating winner');
    });

    it('should revert for non-member', async () => {
      await expect(
        equbPool.schedulePayoutStream(poolId, treasury.address, ethers.parseEther('10'), 20, 8),
      ).to.be.revertedWith('not rotating winner');
    });

    it('should allow only pool creator to schedule stream', async () => {
      await expect(
        equbPool.connect(user1).schedulePayoutStream(poolId, user1.address, ethers.parseEther('10'), 20, 8),
      ).to.be.revertedWith('only creator');
    });
  });

  describe('triggerDefault access control', () => {
    it('should allow only pool creator to trigger default', async () => {
      await equbPool['createPool(uint8,uint256,uint256,address)'](TIER, CONTRIBUTION, MAX_MEMBERS, treasury.address);
      const poolId = 1;
      await equbPool.connect(user1).joinPool(poolId);

      await expect(
        equbPool.connect(user1).triggerDefault(poolId, user1.address),
      ).to.be.revertedWith('only creator');
    });
  });

  describe('ERC-20 pool contributions', () => {
    let poolId: number;
    let testToken: any;
    const TOKEN_CONTRIBUTION = ethers.parseUnits('100', 6); // 100 USDC

    beforeEach(async () => {
      // Deploy a test ERC-20 token
      const TestTokenFactory = await ethers.getContractFactory('TestToken');
      testToken = await TestTokenFactory.deploy('Test USDC', 'USDC', 6);

      // Mint tokens to users
      await testToken.mint(user1.address, ethers.parseUnits('10000', 6));
      await testToken.mint(user2.address, ethers.parseUnits('10000', 6));

      // Create an ERC-20 pool
      const tokenAddr = await testToken.getAddress();
      await equbPool['createPool(uint8,uint256,uint256,address,address)'](
        TIER, TOKEN_CONTRIBUTION, MAX_MEMBERS, treasury.address, tokenAddr,
      );
      poolId = 1;

      await equbPool.connect(user1).joinPool(poolId);
      await equbPool.connect(user2).joinPool(poolId);
    });

    it('should accept ERC-20 contributions after approval', async () => {
      const equbAddr = await equbPool.getAddress();

      // Approve the EqubPool to spend tokens
      await testToken.connect(user1).approve(equbAddr, TOKEN_CONTRIBUTION);

      // Contribute (no msg.value needed)
      await expect(equbPool.connect(user1).contribute(poolId))
        .to.emit(equbPool, 'ContributionReceived')
        .withArgs(poolId, user1.address, 1);
    });

    it('should revert if user sends CTC to an ERC-20 pool', async () => {
      await expect(
        equbPool.connect(user1).contribute(poolId, { value: TOKEN_CONTRIBUTION }),
      ).to.be.revertedWith('do not send CTC for token pool');
    });

    it('should revert if allowance is insufficient', async () => {
      // No approve call
      await expect(
        equbPool.connect(user1).contribute(poolId),
      ).to.be.revertedWith('insufficient token allowance');
    });

    it('should report the correct pool token', async () => {
      const tokenAddr = await testToken.getAddress();
      expect(await equbPool.poolToken(poolId)).to.equal(tokenAddr);
    });
  });

  describe('Full lifecycle integration', () => {
    it('should complete a full pool lifecycle', async () => {
      // 1. Create pool
      await equbPool['createPool(uint8,uint256,uint256,address)'](TIER, CONTRIBUTION, 3, treasury.address);
      const poolId = 1;

      // 2. Users join
      await equbPool.connect(user1).joinPool(poolId);
      await equbPool.connect(user2).joinPool(poolId);
      await equbPool.connect(user3).joinPool(poolId);

      // 3. Round 1: all contribute
      await equbPool.connect(user1).contribute(poolId, { value: CONTRIBUTION });
      await equbPool.connect(user2).contribute(poolId, { value: CONTRIBUTION });
      await equbPool.connect(user3).contribute(poolId, { value: CONTRIBUTION });

      // 4. Close round 1 -- everyone rewarded
      await equbPool.closeRound(poolId);
      expect(await creditRegistry.scoreOf(user1.address)).to.equal(1);
      expect(await creditRegistry.scoreOf(user2.address)).to.equal(1);
      expect(await creditRegistry.scoreOf(user3.address)).to.equal(1);

      // 5. Schedule payout for user1 (round winner)
      const [, round1Winner] = await equbPool.rotatingWinnerForLastClosedRound(poolId);
      await equbPool.schedulePayoutStream(
        poolId,
        round1Winner,
        ethers.parseEther('3'),
        20,
        2,
      );

      // 6. Round 2: user3 defaults
      await equbPool.connect(user1).contribute(poolId, { value: CONTRIBUTION });
      await equbPool.connect(user2).contribute(poolId, { value: CONTRIBUTION });
      // user3 does NOT contribute

      // 7. Close round 2
      await equbPool.closeRound(poolId);

      // user1 and user2 get +1 more (total 2 each)
      expect(await creditRegistry.scoreOf(user1.address)).to.equal(2);
      expect(await creditRegistry.scoreOf(user2.address)).to.equal(2);
      // user3 got penalized -10 (total = 1 - 10 = -9)
      expect(await creditRegistry.scoreOf(user3.address)).to.equal(-9);
    });

    it('should avoid repeating winners within a season, then reset', async () => {
      await equbPool['createPool(uint8,uint256,uint256,address)'](TIER, CONTRIBUTION, 3, treasury.address);
      const poolId = 1;

      await equbPool.connect(user1).joinPool(poolId);
      await equbPool.connect(user2).joinPool(poolId);
      await equbPool.connect(user3).joinPool(poolId);

      const winners: string[] = [];

      for (let r = 0; r < 3; r++) {
        await equbPool.connect(user1).contribute(poolId, { value: CONTRIBUTION });
        await equbPool.connect(user2).contribute(poolId, { value: CONTRIBUTION });
        await equbPool.connect(user3).contribute(poolId, { value: CONTRIBUTION });
        await equbPool.closeRound(poolId);
        const [, winner] = await equbPool.rotatingWinnerForLastClosedRound(poolId);
        winners.push(winner.toLowerCase());
      }

      const unique = new Set(winners);
      expect(unique.size).to.equal(3);

      // Round 4 starts a new season and winner can repeat
      await equbPool.connect(user1).contribute(poolId, { value: CONTRIBUTION });
      await equbPool.connect(user2).contribute(poolId, { value: CONTRIBUTION });
      await equbPool.connect(user3).contribute(poolId, { value: CONTRIBUTION });
      await equbPool.closeRound(poolId);
      const [, round4Winner] = await equbPool.rotatingWinnerForLastClosedRound(poolId);

      expect(
        [user1.address.toLowerCase(), user2.address.toLowerCase(), user3.address.toLowerCase()].includes(
          round4Winner.toLowerCase(),
        ),
      ).to.equal(true);
    });
  });
});
