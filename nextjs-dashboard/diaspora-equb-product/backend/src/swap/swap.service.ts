import { Injectable, Logger, BadRequestException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ethers } from 'ethers';
import { Web3Service, UnsignedTxDto } from '../web3/web3.service';

@Injectable()
export class SwapService {
  private readonly logger = new Logger(SwapService.name);
  private static readonly ZERO_ADDRESS =
    '0x0000000000000000000000000000000000000000';
  private readonly tokenAddresses: Record<string, string>;
  private readonly nativeSymbol: string;

  constructor(
    private readonly web3Service: Web3Service,
    private readonly configService: ConfigService,
  ) {
    this.nativeSymbol =
      this.configService.get<number>('CHAIN_ID', 102031) === 102030
        ? 'CTC'
        : 'tCTC';
    this.tokenAddresses = {
      USDC: this.configService.get<string>(
        'TEST_USDC_ADDRESS',
        SwapService.ZERO_ADDRESS,
      ),
      USDT: this.configService.get<string>(
        'TEST_USDT_ADDRESS',
        SwapService.ZERO_ADDRESS,
      ),
    };
  }

  getStatus(): {
    routerConfigured: boolean;
    routerAddress: string;
    nativeSymbol: string;
    supportedTokens: Array<{ symbol: string; address: string }>;
  } {
    const routerAddress = this.getRouterAddress();
    return {
      routerConfigured: !this.isZeroAddress(routerAddress),
      routerAddress,
      nativeSymbol: this.nativeSymbol,
      supportedTokens: Object.entries(this.tokenAddresses)
        .filter(([, address]) => !this.isZeroAddress(address))
        .map(([symbol, address]) => ({ symbol, address })),
    };
  }

  /**
   * Get a swap quote from the on-chain SwapRouter.
   * Determines direction from the special "CTC" sentinel vs ERC-20 addresses.
   */
  async getQuote(
    fromToken: string,
    toToken: string,
    amountIn: string,
  ): Promise<{
    amountIn: string;
    amountInRaw: string;
    estimatedOutput: string;
    estimatedOutputRaw: string;
    priceImpactPct: string;
    fee: string;
    feeRaw: string;
    inputDecimals: number;
    outputDecimals: number;
  }> {
    this.ensureRouterConfigured();

    const { token, ctcToToken, inputDecimals, outputDecimals } =
      this.resolveDirection(fromToken, toToken);
    const router = this.web3Service.getSwapRouter();
    const amountInBn = this.parseHumanAmount(amountIn, inputDecimals);

    if (amountInBn <= 0n) {
      throw new BadRequestException('Swap amount must be greater than zero');
    }

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
      amountIn: amountIn.trim(),
      amountInRaw: amountInBn.toString(),
      estimatedOutput: this.formatAmount(
        BigInt(estimatedOutput.toString()),
        outputDecimals,
      ),
      estimatedOutputRaw: estimatedOutput.toString(),
      priceImpactPct: priceImpact,
      fee: this.formatAmount(feeAmount, inputDecimals),
      feeRaw: feeAmount.toString(),
      inputDecimals,
      outputDecimals,
    };
  }

  /**
   * Build an unsigned swap transaction for the client to sign.
   */
  async buildSwapTx(
    fromToken: string,
    toToken: string,
    amountInRaw: string,
    minAmountOutRaw: string,
  ): Promise<UnsignedTxDto> {
    this.ensureRouterConfigured();

    const { token, ctcToToken } = this.resolveDirection(fromToken, toToken);
    const router = this.web3Service.getSwapRouter();
    const routerAddress = await router.getAddress();
    const parsedAmountIn = this.parseRawAmount(amountInRaw, 'amountInRaw');
    const parsedMinAmountOut = this.parseRawAmount(
      minAmountOutRaw,
      'minAmountOutRaw',
    );

    let data: string;
    let value: string;

    if (ctcToToken) {
      data = router.interface.encodeFunctionData('swapCTCForToken', [
        token,
        parsedMinAmountOut.toString(),
      ]);
      value = parsedAmountIn.toString();
    } else {
      data = router.interface.encodeFunctionData('swapTokenForCTC', [
        token,
        parsedAmountIn.toString(),
        parsedMinAmountOut.toString(),
      ]);
      value = '0';
    }

    return this.web3Service.buildUnsignedTx(routerAddress, data, value, '300000');
  }

  async buildApprovalTx(
    fromToken: string,
    amountInRaw: string,
  ): Promise<UnsignedTxDto> {
    this.ensureRouterConfigured();

    const token = this.resolveErc20Token(fromToken);
    const amount = this.parseRawAmount(amountInRaw, 'amountInRaw');
    const routerAddress = this.getRouterAddress();
    const erc20Iface = new ethers.Interface([
      'function approve(address spender, uint256 amount) external returns (bool)',
    ]);

    const data = erc20Iface.encodeFunctionData('approve', [
      routerAddress,
      amount.toString(),
    ]);

    return this.web3Service.buildUnsignedTx(token.address, data, '0', '120000');
  }

  /**
   * Get reserves for a token pool.
   */
  async getReserves(token: string): Promise<{ ctcReserve: string; tokenReserve: string }> {
    this.ensureRouterConfigured();

    const router = this.web3Service.getSwapRouter();
    const resolvedToken = this.resolveErc20Token(token);
    const [ctcReserve, tokenReserve] = await router.getReserves(resolvedToken.address);
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
  ): {
    token: string;
    ctcToToken: boolean;
    inputDecimals: number;
    outputDecimals: number;
  } {
    const CTC_SENTINEL = SwapService.ZERO_ADDRESS;
    const fromIsCTC =
      fromToken.toUpperCase() === 'CTC' ||
      fromToken.toUpperCase() === 'TCTC' ||
      fromToken.toLowerCase() === CTC_SENTINEL.toLowerCase();
    const toIsCTC =
      toToken.toUpperCase() === 'CTC' ||
      toToken.toUpperCase() === 'TCTC' ||
      toToken.toLowerCase() === CTC_SENTINEL.toLowerCase();

    if (fromIsCTC && toIsCTC) {
      throw new BadRequestException('Cannot swap CTC to CTC');
    }
    if (!fromIsCTC && !toIsCTC) {
      throw new BadRequestException(
        'Direct token-to-token swaps not supported. Route through CTC.',
      );
    }

    const erc20Token = this.resolveErc20Token(fromIsCTC ? toToken : fromToken);
    const inputDecimals = fromIsCTC ? 18 : erc20Token.decimals;
    const outputDecimals = toIsCTC ? 18 : erc20Token.decimals;

    return {
      token: erc20Token.address,
      ctcToToken: fromIsCTC,
      inputDecimals,
      outputDecimals,
    };
  }

  private resolveErc20Token(token: string): {
    symbol: string;
    address: string;
    decimals: number;
  } {
    const normalized = token.trim();
    if (!normalized) {
      throw new BadRequestException('Token is required');
    }

    const upper = normalized.toUpperCase();
    if (upper === 'CTC' || upper === 'TCTC') {
      throw new BadRequestException('Native token cannot be used as ERC-20 token');
    }

    if (this.tokenAddresses[upper] && !this.isZeroAddress(this.tokenAddresses[upper])) {
      return {
        symbol: upper,
        address: this.tokenAddresses[upper],
        decimals: upper == 'USDC' || upper == 'USDT' ? 6 : 18,
      };
    }

    if (/^0x[a-fA-F0-9]{40}$/.test(normalized)) {
      return {
        symbol: normalized,
        address: normalized,
        decimals: 18,
      };
    }

    throw new BadRequestException(`Unsupported swap token: ${token}`);
  }

  private ensureRouterConfigured(): void {
    const routerAddress = this.getRouterAddress();
    if (this.isZeroAddress(routerAddress)) {
      throw new BadRequestException(
        'Swap router is not configured for this environment',
      );
    }
  }

  private getRouterAddress(): string {
    return this.configService.get<string>(
      'SWAP_ROUTER_ADDRESS',
      SwapService.ZERO_ADDRESS,
    );
  }

  private isZeroAddress(address: string): boolean {
    return !address || address.toLowerCase() === SwapService.ZERO_ADDRESS;
  }

  private parseHumanAmount(amount: string, decimals: number): bigint {
    const trimmed = amount.trim();
    if (!trimmed) {
      throw new BadRequestException('Amount is required');
    }

    try {
      return BigInt(ethers.parseUnits(trimmed, decimals).toString());
    } catch {
      throw new BadRequestException(`Invalid swap amount: ${amount}`);
    }
  }

  private parseRawAmount(amount: string, fieldName: string): bigint {
    const trimmed = amount.trim();
    if (!/^\d+$/.test(trimmed)) {
      throw new BadRequestException(`${fieldName} must be a raw integer amount`);
    }

    const parsed = BigInt(trimmed);
    if (parsed <= 0n) {
      throw new BadRequestException(`${fieldName} must be greater than zero`);
    }

    return parsed;
  }

  private formatAmount(amount: bigint, decimals: number): string {
    return ethers.formatUnits(amount, decimals);
  }
}
