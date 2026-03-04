import { expect } from 'chai';
import { ethers } from 'hardhat';
import { SwapRouter } from '../typechain-types';
import { SignerWithAddress } from '@nomicfoundation/hardhat-ethers/signers';

describe('SwapRouter', () => {
  let router: SwapRouter;
  let testToken: any;
  let owner: SignerWithAddress;
  let lp: SignerWithAddress;
  let trader: SignerWithAddress;

  const INITIAL_CTC = ethers.parseEther('100');
  const INITIAL_TOKENS = ethers.parseUnits('10000', 6);

  beforeEach(async () => {
    [owner, lp, trader] = await ethers.getSigners();

    const SwapRouterFactory = await ethers.getContractFactory('SwapRouter');
    router = await SwapRouterFactory.deploy();

    const TestTokenFactory = await ethers.getContractFactory('TestToken');
    testToken = await TestTokenFactory.deploy('Test USDC', 'USDC', 6);

    await testToken.mint(lp.address, ethers.parseUnits('1000000', 6));
    await testToken.mint(trader.address, ethers.parseUnits('100000', 6));
  });

  describe('addLiquidity', () => {
    it('should allow first provider to set ratio', async () => {
      const tokenAddr = await testToken.getAddress();
      await testToken.connect(lp).approve(await router.getAddress(), INITIAL_TOKENS);

      await expect(
        router.connect(lp).addLiquidity(tokenAddr, { value: INITIAL_CTC }),
      )
        .to.emit(router, 'LiquidityAdded')
        .withArgs(lp.address, tokenAddr, INITIAL_CTC, INITIAL_TOKENS, INITIAL_CTC);

      const [ctcReserve, tokenReserve] = await router.getReserves(tokenAddr);
      expect(ctcReserve).to.equal(INITIAL_CTC);
      expect(tokenReserve).to.equal(INITIAL_TOKENS);
    });

    it('should require proportional deposit for subsequent providers', async () => {
      const tokenAddr = await testToken.getAddress();
      const routerAddr = await router.getAddress();

      await testToken.connect(lp).approve(routerAddr, INITIAL_TOKENS);
      await router.connect(lp).addLiquidity(tokenAddr, { value: INITIAL_CTC });

      // Second provider adds 50 CTC → should need 5000 tokens (proportional)
      const secondCTC = ethers.parseEther('50');
      const expectedTokens = ethers.parseUnits('5000', 6);
      await testToken.mint(trader.address, expectedTokens);
      await testToken.connect(trader).approve(routerAddr, expectedTokens);

      await router.connect(trader).addLiquidity(tokenAddr, { value: secondCTC });

      const [ctcReserve, tokenReserve] = await router.getReserves(tokenAddr);
      expect(ctcReserve).to.equal(INITIAL_CTC + secondCTC);
      expect(tokenReserve).to.equal(INITIAL_TOKENS + expectedTokens);
    });

    it('should revert with zero CTC', async () => {
      const tokenAddr = await testToken.getAddress();
      await expect(
        router.connect(lp).addLiquidity(tokenAddr, { value: 0 }),
      ).to.be.revertedWith('must send CTC');
    });

    it('should revert with zero token address', async () => {
      await expect(
        router.connect(lp).addLiquidity(ethers.ZeroAddress, { value: INITIAL_CTC }),
      ).to.be.revertedWith('invalid token');
    });

    it('should revert if no tokens approved', async () => {
      const tokenAddr = await testToken.getAddress();
      await expect(
        router.connect(lp).addLiquidity(tokenAddr, { value: INITIAL_CTC }),
      ).to.be.revertedWith('must approve tokens');
    });
  });

  describe('removeLiquidity', () => {
    beforeEach(async () => {
      const tokenAddr = await testToken.getAddress();
      await testToken.connect(lp).approve(await router.getAddress(), INITIAL_TOKENS);
      await router.connect(lp).addLiquidity(tokenAddr, { value: INITIAL_CTC });
    });

    it('should remove partial liquidity', async () => {
      const tokenAddr = await testToken.getAddress();
      const sharesToBurn = INITIAL_CTC / 2n;

      await expect(
        router.connect(lp).removeLiquidity(tokenAddr, sharesToBurn),
      ).to.emit(router, 'LiquidityRemoved');

      const [ctcReserve, tokenReserve] = await router.getReserves(tokenAddr);
      expect(ctcReserve).to.equal(INITIAL_CTC / 2n);
      expect(tokenReserve).to.equal(INITIAL_TOKENS / 2n);
    });

    it('should remove all liquidity', async () => {
      const tokenAddr = await testToken.getAddress();
      await router.connect(lp).removeLiquidity(tokenAddr, INITIAL_CTC);

      const [ctcReserve, tokenReserve] = await router.getReserves(tokenAddr);
      expect(ctcReserve).to.equal(0);
      expect(tokenReserve).to.equal(0);
    });

    it('should revert with zero shares', async () => {
      const tokenAddr = await testToken.getAddress();
      await expect(
        router.connect(lp).removeLiquidity(tokenAddr, 0),
      ).to.be.revertedWith('zero shares');
    });

    it('should revert with insufficient shares', async () => {
      const tokenAddr = await testToken.getAddress();
      await expect(
        router.connect(trader).removeLiquidity(tokenAddr, 1),
      ).to.be.revertedWith('insufficient shares');
    });
  });

  describe('swapCTCForToken', () => {
    beforeEach(async () => {
      const tokenAddr = await testToken.getAddress();
      await testToken.connect(lp).approve(await router.getAddress(), INITIAL_TOKENS);
      await router.connect(lp).addLiquidity(tokenAddr, { value: INITIAL_CTC });
    });

    it('should swap CTC for tokens with correct output', async () => {
      const tokenAddr = await testToken.getAddress();
      const swapAmount = ethers.parseEther('1');

      // Manual constant-product calculation:
      // amountInWithFee = 1e18 * 997 = 997e15
      // numerator = 997e15 * 10000e6 = 997e25
      // denominator = (100e18 * 1000) + 997e15 = 100000e15 + 997e15 = 100997e15
      // amountOut = 997e25 / 100997e15 ≈ 98.71e6
      const expectedMin = ethers.parseUnits('98', 6);

      await expect(
        router.connect(trader).swapCTCForToken(tokenAddr, expectedMin, { value: swapAmount }),
      ).to.emit(router, 'Swap');
    });

    it('should revert with zero CTC', async () => {
      const tokenAddr = await testToken.getAddress();
      await expect(
        router.connect(trader).swapCTCForToken(tokenAddr, 0, { value: 0 }),
      ).to.be.revertedWith('must send CTC');
    });

    it('should revert when slippage exceeded', async () => {
      const tokenAddr = await testToken.getAddress();
      const swapAmount = ethers.parseEther('1');
      const tooHighMin = ethers.parseUnits('200', 6);

      await expect(
        router.connect(trader).swapCTCForToken(tokenAddr, tooHighMin, { value: swapAmount }),
      ).to.be.revertedWith('slippage exceeded');
    });
  });

  describe('swapTokenForCTC', () => {
    beforeEach(async () => {
      const tokenAddr = await testToken.getAddress();
      await testToken.connect(lp).approve(await router.getAddress(), INITIAL_TOKENS);
      await router.connect(lp).addLiquidity(tokenAddr, { value: INITIAL_CTC });
    });

    it('should swap tokens for CTC', async () => {
      const tokenAddr = await testToken.getAddress();
      const routerAddr = await router.getAddress();
      const swapAmount = ethers.parseUnits('100', 6);

      await testToken.connect(trader).approve(routerAddr, swapAmount);

      await expect(
        router.connect(trader).swapTokenForCTC(tokenAddr, swapAmount, 0),
      ).to.emit(router, 'Swap');
    });

    it('should revert with zero input', async () => {
      const tokenAddr = await testToken.getAddress();
      await expect(
        router.connect(trader).swapTokenForCTC(tokenAddr, 0, 0),
      ).to.be.revertedWith('zero input');
    });

    it('should revert when slippage exceeded', async () => {
      const tokenAddr = await testToken.getAddress();
      const routerAddr = await router.getAddress();
      const swapAmount = ethers.parseUnits('100', 6);
      const tooHighMin = ethers.parseEther('1000');

      await testToken.connect(trader).approve(routerAddr, swapAmount);

      await expect(
        router.connect(trader).swapTokenForCTC(tokenAddr, swapAmount, tooHighMin),
      ).to.be.revertedWith('slippage exceeded');
    });
  });

  describe('getQuote', () => {
    beforeEach(async () => {
      const tokenAddr = await testToken.getAddress();
      await testToken.connect(lp).approve(await router.getAddress(), INITIAL_TOKENS);
      await router.connect(lp).addLiquidity(tokenAddr, { value: INITIAL_CTC });
    });

    it('should return correct quote for CTC to token', async () => {
      const tokenAddr = await testToken.getAddress();
      const amountIn = ethers.parseEther('1');

      const quote = await router.getQuote(tokenAddr, amountIn, true);
      expect(quote).to.be.gt(0);
    });

    it('should return correct quote for token to CTC', async () => {
      const tokenAddr = await testToken.getAddress();
      const amountIn = ethers.parseUnits('100', 6);

      const quote = await router.getQuote(tokenAddr, amountIn, false);
      expect(quote).to.be.gt(0);
    });

    it('should match actual swap output', async () => {
      const tokenAddr = await testToken.getAddress();
      const amountIn = ethers.parseEther('1');

      const quote = await router.getQuote(tokenAddr, amountIn, true);

      const balBefore = await testToken.balanceOf(trader.address);
      await router.connect(trader).swapCTCForToken(tokenAddr, 0, { value: amountIn });
      const balAfter = await testToken.balanceOf(trader.address);

      expect(balAfter - balBefore).to.equal(quote);
    });

    it('should revert with no liquidity', async () => {
      const TestTokenFactory = await ethers.getContractFactory('TestToken');
      const otherToken = await TestTokenFactory.deploy('Other', 'OTH', 18);
      const otherAddr = await otherToken.getAddress();

      await expect(
        router.getQuote(otherAddr, ethers.parseEther('1'), true),
      ).to.be.revertedWith('no liquidity');
    });
  });

  describe('getReserves', () => {
    it('should return zero for uninitialized pool', async () => {
      const tokenAddr = await testToken.getAddress();
      const [ctc, token] = await router.getReserves(tokenAddr);
      expect(ctc).to.equal(0);
      expect(token).to.equal(0);
    });

    it('should return correct reserves after adding liquidity', async () => {
      const tokenAddr = await testToken.getAddress();
      await testToken.connect(lp).approve(await router.getAddress(), INITIAL_TOKENS);
      await router.connect(lp).addLiquidity(tokenAddr, { value: INITIAL_CTC });

      const [ctc, token] = await router.getReserves(tokenAddr);
      expect(ctc).to.equal(INITIAL_CTC);
      expect(token).to.equal(INITIAL_TOKENS);
    });

    it('should update reserves after a swap', async () => {
      const tokenAddr = await testToken.getAddress();
      await testToken.connect(lp).approve(await router.getAddress(), INITIAL_TOKENS);
      await router.connect(lp).addLiquidity(tokenAddr, { value: INITIAL_CTC });

      const swapAmount = ethers.parseEther('10');
      await router.connect(trader).swapCTCForToken(tokenAddr, 0, { value: swapAmount });

      const [ctc, token] = await router.getReserves(tokenAddr);
      expect(ctc).to.equal(INITIAL_CTC + swapAmount);
      expect(token).to.be.lt(INITIAL_TOKENS);
    });
  });
});
