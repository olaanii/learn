import { Injectable, Logger, BadRequestException } from '@nestjs/common';
import { ethers } from 'ethers';
import { Web3Service, UnsignedTxDto } from '../web3/web3.service';

@Injectable()
export class SwapService {
  private readonly logger = new Logger(SwapService.name);

  constructor(private readonly web3Service: Web3Service) {}

  /**
   * Get a swap quote from the on-chain SwapRouter.
   * Determines direction from the special "CTC" sentinel vs ERC-20 addresses.
   */
  async getQuote(
    fromToken: string,
    toToken: string,
    amountIn: string,
  ): Promise<{ estimatedOutput: string; priceImpact: string; fee: string }> {
    const { token, ctcToToken } = this.resolveDirection(fromToken, toToken);
    const router = this.web3Service.getSwapRouter();
    const amountInBn = BigInt(amountIn);

    const [ctcReserve, tokenReserve] = await router.getReserves(token);
    const ctcRes = BigInt(ctcReserve.toString());
    const tokenRes = BigInt(tokenReserve.toString());

    if (ctcRes === 0n || tokenRes === 0n) {
      throw new BadRequestException('No liquidity for this token pair');
    }

    const estimatedOutput: bigint = await router.getQuote(token, amountInBn, ctcToToken);

    const inputReserve = ctcToToken ? ctcRes : tokenRes;
    const idealOutput = ctcToToken
      ? (amountInBn * tokenRes) / inputReserve
      : (amountInBn * ctcRes) / inputReserve;

    let priceImpact = '0';
    if (idealOutput > 0n) {
      const impactBps = ((idealOutput - BigInt(estimatedOutput.toString())) * 10000n) / idealOutput;
      priceImpact = (Number(impactBps) / 100).toFixed(2);
    }

    const feeAmount = (amountInBn * 3n) / 1000n;

    return {
      estimatedOutput: estimatedOutput.toString(),
      priceImpact: `${priceImpact}%`,
      fee: feeAmount.toString(),
    };
  }

  /**
   * Build an unsigned swap transaction for the client to sign.
   */
  async buildSwapTx(
    fromToken: string,
    toToken: string,
    amountIn: string,
    minAmountOut: string,
  ): Promise<UnsignedTxDto> {
    const { token, ctcToToken } = this.resolveDirection(fromToken, toToken);
    const router = this.web3Service.getSwapRouter();
    const routerAddress = await router.getAddress();

    let data: string;
    let value: string;

    if (ctcToToken) {
      data = router.interface.encodeFunctionData('swapCTCForToken', [
        token,
        minAmountOut,
      ]);
      value = amountIn;
    } else {
      data = router.interface.encodeFunctionData('swapTokenForCTC', [
        token,
        amountIn,
        minAmountOut,
      ]);
      value = '0';
    }

    return this.web3Service.buildUnsignedTx(routerAddress, data, value, '300000');
  }

  /**
   * Get reserves for a token pool.
   */
  async getReserves(token: string): Promise<{ ctcReserve: string; tokenReserve: string }> {
    const router = this.web3Service.getSwapRouter();
    const [ctcReserve, tokenReserve] = await router.getReserves(token);
    return {
      ctcReserve: ctcReserve.toString(),
      tokenReserve: tokenReserve.toString(),
    };
  }

  /**
   * Placeholder for swap history. In production, this would query
   * indexed Swap events from a database.
   */
  async getSwapHistory(walletAddress: string): Promise<any[]> {
    this.logger.log(`Swap history requested for ${walletAddress} (placeholder)`);
    return [];
  }

  private resolveDirection(
    fromToken: string,
    toToken: string,
  ): { token: string; ctcToToken: boolean } {
    const CTC_SENTINEL = '0x0000000000000000000000000000000000000000';
    const fromIsCTC =
      fromToken.toUpperCase() === 'CTC' ||
      fromToken.toLowerCase() === CTC_SENTINEL.toLowerCase();
    const toIsCTC =
      toToken.toUpperCase() === 'CTC' ||
      toToken.toLowerCase() === CTC_SENTINEL.toLowerCase();

    if (fromIsCTC && toIsCTC) {
      throw new BadRequestException('Cannot swap CTC to CTC');
    }
    if (!fromIsCTC && !toIsCTC) {
      throw new BadRequestException(
        'Direct token-to-token swaps not supported. Route through CTC.',
      );
    }

    return {
      token: fromIsCTC ? toToken : fromToken,
      ctcToToken: fromIsCTC,
    };
  }
}
