import {
  Injectable,
  Logger,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ConfigService } from '@nestjs/config';
import { ethers } from 'ethers';
import { Collateral } from '../entities/collateral.entity';
import { Web3Service, UnsignedTxDto } from '../web3/web3.service';
import { NotificationsService } from '../notifications/notifications.service';

const ERC20_IFACE = new ethers.Interface([
  'function transfer(address to, uint256 amount) returns (bool)',
  'function balanceOf(address) view returns (uint256)',
  'function decimals() view returns (uint8)',
]);

@Injectable()
export class CollateralService {
  private readonly logger = new Logger(CollateralService.name);
  private readonly tokenAddresses: Record<string, string> = {};

  constructor(
    @InjectRepository(Collateral)
    private readonly collateralRepo: Repository<Collateral>,
    private readonly web3Service: Web3Service,
    private readonly configService: ConfigService,
    private readonly notifications: NotificationsService,
  ) {
    this.tokenAddresses = {
      USDC: this.configService.get<string>(
        'TEST_USDC_ADDRESS',
        '0x0000000000000000000000000000000000000000',
      ),
      USDT: this.configService.get<string>(
        'TEST_USDT_ADDRESS',
        '0x0000000000000000000000000000000000000000',
      ),
    };
  }

  private getTokenAddress(symbol: string): string {
    const addr = this.tokenAddresses[symbol.toUpperCase()];
    if (!addr || addr === '0x0000000000000000000000000000000000000000') {
      throw new BadRequestException(
        `Token ${symbol} not deployed. Deploy test tokens first.`,
      );
    }
    return addr;
  }

  private async getTokenDecimals(symbol: string): Promise<number> {
    const addr = this.getTokenAddress(symbol);
    const contract = new ethers.Contract(
      addr,
      ERC20_IFACE,
      this.web3Service.getProvider(),
    );
    return Number(await contract.decimals());
  }

  // ─── Native CTC TX Builders (kept for backward compat) ─────────────────────

  async buildDeposit(amount: string): Promise<UnsignedTxDto> {
    this.logger.log(`Building depositCollateral TX (CTC): amount=${amount}`);
    const collateralVault = this.web3Service.getCollateralVault();
    const data =
      collateralVault.interface.encodeFunctionData('depositCollateral');
    const to = await collateralVault.getAddress();
    return this.web3Service.buildUnsignedTx(to, data, amount, '100000');
  }

  async buildRelease(
    userAddress: string,
    amount: string,
  ): Promise<UnsignedTxDto> {
    this.logger.log(
      `Building releaseCollateral TX (CTC): user=${userAddress}, amount=${amount}`,
    );
    const collateralVault = this.web3Service.getCollateralVault();
    const data = collateralVault.interface.encodeFunctionData(
      'releaseCollateral',
      [userAddress, amount],
    );
    const to = await collateralVault.getAddress();
    return this.web3Service.buildUnsignedTx(to, data, '0', '100000');
  }

  // ─── ERC-20 Token Collateral ───────────────────────────────────────────────

  /**
   * Build unsigned TX to deposit USDC/USDT as collateral.
   * Transfers tokens from the user to the deployer address (acts as vault).
    * The user signs this with their wallet; balance is deducted on-chain.
   */
  async buildDepositToken(
    amount: string,
    tokenSymbol: string = 'USDC',
  ): Promise<UnsignedTxDto & { tokenAddress: string; decimals: number }> {
    const tokenAddress = this.getTokenAddress(tokenSymbol);
    const decimals = await this.getTokenDecimals(tokenSymbol);
    const amountWei = ethers.parseUnits(amount, decimals);

    const signer = this.web3Service.getDeployerSigner();
    if (!signer) {
      throw new BadRequestException(
        'Deployer not configured — cannot accept token collateral.',
      );
    }
    const vaultAddress = signer.address;

    this.logger.log(
      `Building token collateral deposit: ${amount} ${tokenSymbol} → ${vaultAddress}`,
    );

    const data = ERC20_IFACE.encodeFunctionData('transfer', [
      vaultAddress,
      amountWei,
    ]);

    return {
      ...this.web3Service.buildUnsignedTx(tokenAddress, data, '0', '80000'),
      tokenAddress,
      decimals,
    };
  }

  /**
   * Called after the user's deposit TX is confirmed on-chain.
   * Records the collateral in the DB so the UI can display it.
   */
  async confirmTokenDeposit(
    walletAddress: string,
    amount: string,
    tokenSymbol: string,
    txHash: string,
  ) {
    this.logger.log(
      `Confirming token collateral deposit: ${amount} ${tokenSymbol}, wallet=${walletAddress}, tx=${txHash}`,
    );

    let collateral = await this.collateralRepo.findOne({
      where: { walletAddress, poolId: undefined },
    });

    if (!collateral) {
      collateral = this.collateralRepo.create({
        walletAddress,
        lockedAmount: '0',
        slashedAmount: '0',
        availableBalance: '0',
      });
    }

    const lockAmount = this.parseAmountToBigInt(amount);
    const currentLocked = this.parseAmountToBigInt(collateral.lockedAmount);
    collateral.lockedAmount = (currentLocked + lockAmount).toString();
    await this.collateralRepo.save(collateral);

    this.notifications
      .create(
        walletAddress,
        'collateral_deposit_confirmed',
        'Collateral Deposit Confirmed',
        `${amount} ${tokenSymbol.toUpperCase()} collateral deposit was confirmed.`,
        {
          amount,
          token: tokenSymbol.toUpperCase(),
          txHash,
          lockedAmount: collateral.lockedAmount,
          idempotencyKey: `collateral_deposit_confirmed:${walletAddress.toLowerCase()}:${tokenSymbol.toUpperCase()}:${amount}:${txHash.toLowerCase()}`,
        },
      )
      .catch((error) => {
        this.logger.warn(`Failed to emit collateral_deposit_confirmed notification: ${error?.message ?? error}`);
      });

    return {
      walletAddress,
      amount,
      tokenSymbol,
      txHash,
      lockedAmount: collateral.lockedAmount,
      availableBalance: collateral.availableBalance,
      status: 'confirmed',
    };
  }

  /**
   * Release token collateral: the deployer sends USDC/USDT back to the user.
   * Executed server-side (like the faucet).
   */
  async releaseTokenCollateral(
    walletAddress: string,
    amount: string,
    tokenSymbol: string = 'USDC',
  ) {
    try {
      const signer = this.web3Service.getDeployerSigner();
      if (!signer) {
        throw new BadRequestException(
          'Deployer not configured — cannot release token collateral.',
        );
      }

      const tokenAddress = this.getTokenAddress(tokenSymbol);
      const decimals = await this.getTokenDecimals(tokenSymbol);
      const amountWei = ethers.parseUnits(amount, decimals);

      // Verify the user has enough locked collateral
      const collateral = await this.collateralRepo.findOne({
        where: { walletAddress },
      });
      if (!collateral) {
        throw new NotFoundException('No collateral found for this wallet');
      }

      const currentLocked = this.parseAmountToBigInt(collateral.lockedAmount);
      const releaseAmt = this.parseAmountToBigInt(amount);
      if (releaseAmt > currentLocked) {
        throw new BadRequestException(
          `Release amount exceeds locked balance (locked: ${collateral.lockedAmount})`,
        );
      }

      this.logger.log(
        `Releasing token collateral: ${amount} ${tokenSymbol} → ${walletAddress}`,
      );

      const contract = new ethers.Contract(tokenAddress, ERC20_IFACE, signer);
      const tx = await contract.transfer(walletAddress, amountWei);
      const receipt = await tx.wait();

      // Update DB
      collateral.lockedAmount = (currentLocked - releaseAmt).toString();
      const currentAvailable = this.parseAmountToBigInt(
        collateral.availableBalance,
      );
      collateral.availableBalance = (currentAvailable + releaseAmt).toString();
      await this.collateralRepo.save(collateral);

      this.logger.log(
        `Token collateral released in block ${receipt.blockNumber}: ${tx.hash}`,
      );

      this.notifications
        .create(
          walletAddress,
          'collateral_released',
          'Collateral Released',
          `${amount} ${tokenSymbol.toUpperCase()} collateral has been released to your wallet.`,
          {
            amount,
            token: tokenSymbol.toUpperCase(),
            txHash: tx.hash,
            status: 'confirmed',
            kind: 'transaction',
            lockedAmount: collateral.lockedAmount,
            availableBalance: collateral.availableBalance,
            idempotencyKey: `collateral_released:${walletAddress.toLowerCase()}:${tokenSymbol.toUpperCase()}:${amount}:${tx.hash.toLowerCase()}`,
          },
        )
        .catch((error) => {
          this.logger.warn(`Failed to emit collateral_released notification: ${error?.message ?? error}`);
        });

      return {
        walletAddress,
        amount,
        tokenSymbol,
        txHash: tx.hash,
        lockedAmount: collateral.lockedAmount,
        availableBalance: collateral.availableBalance,
        status: 'released',
      };
    } catch (error) {
      this.notifications
        .create(
          walletAddress,
          'collateral_released',
          'Collateral Release Failed',
          `Collateral release failed for ${amount} ${tokenSymbol.toUpperCase()}.`,
          {
            amount,
            token: tokenSymbol.toUpperCase(),
            status: 'failed',
            kind: 'transaction',
            error: (error as any)?.message ?? String(error),
            idempotencyKey: `collateral_released_failed:${walletAddress.toLowerCase()}:${tokenSymbol.toUpperCase()}:${amount}`,
          },
        )
        .catch((emitError) => {
          this.logger.warn(`Failed to emit collateral release failure notification: ${emitError?.message ?? emitError}`);
        });
      throw error;
    }
  }

  // ─── Read Methods ──────────────────────────────────────────────────────────

  /**
   * Get collateral data: first tries on-chain CTC vault, then merges with
   * DB-tracked token collateral for a complete picture.
   */
  async getCollateral(walletAddress: string) {
    const results: any[] = [];

    // DB-tracked token collateral (USDC/USDT deposits)
    const dbCollaterals = await this.collateralRepo.find({
      where: { walletAddress },
    });

    if (dbCollaterals.length > 0) {
      for (const c of dbCollaterals) {
        results.push({
          walletAddress: c.walletAddress,
          lockedAmount: c.lockedAmount,
          availableBalance: c.availableBalance,
          slashedAmount: c.slashedAmount,
          poolId: c.poolId || null,
          source: 'token',
        });
      }
    }

    // On-chain CTC collateral from CollateralVault
    try {
      const collateralVault = this.web3Service.getCollateralVault();
      const onChainBalance: bigint =
        await collateralVault.collateralOf(walletAddress);
      const onChainLocked: bigint =
        await collateralVault.lockedOf(walletAddress);

      if (onChainBalance > 0n || onChainLocked > 0n) {
        results.push({
          walletAddress,
          lockedAmount: onChainLocked.toString(),
          availableBalance: onChainBalance.toString(),
          slashedAmount: '0',
          source: 'on-chain-ctc',
        });
      }
    } catch (e) {
      this.logger.warn(
        `On-chain collateral read failed: ${e.message}`,
      );
    }

    // If no collateral found anywhere, return empty array
    if (results.length === 0 && dbCollaterals.length === 0) {
      return [];
    }

    return results;
  }

  // ─── Legacy DB Methods (kept for dev/test) ──────────────────────────────────

  /** Parse amount to integer string for BigInt (avoids float → BigInt error). */
  private parseAmountToBigInt(value: string | number): bigint {
    const s = typeof value === 'number' ? String(Math.trunc(value)) : String(value).split('.')[0]?.trim() ?? '0';
    return BigInt(s || '0');
  }

  async lock(walletAddress: string, amount: string, poolId?: string) {
    this.logger.log(
      `Locking collateral (DB): wallet=${walletAddress}, amount=${amount}`,
    );

    let collateral = await this.collateralRepo.findOne({
      where: { walletAddress, poolId: poolId || undefined },
    });

    if (!collateral) {
      collateral = this.collateralRepo.create({
        walletAddress,
        poolId,
        lockedAmount: '0',
        slashedAmount: '0',
        availableBalance: '0',
      });
    }

    const currentLocked = this.parseAmountToBigInt(collateral.lockedAmount);
    const lockAmount = this.parseAmountToBigInt(amount);
    collateral.lockedAmount = (currentLocked + lockAmount).toString();

    await this.collateralRepo.save(collateral);

    return {
      walletAddress,
      amount,
      poolId,
      lockedAmount: collateral.lockedAmount,
      status: 'locked',
    };
  }

  async slash(walletAddress: string, amount: string, poolId?: string) {
    this.logger.log(
      `Slashing collateral: wallet=${walletAddress}, amount=${amount}`,
    );

    const collateral = await this.collateralRepo.findOne({
      where: { walletAddress, poolId: poolId || undefined },
    });

    if (!collateral) {
      throw new NotFoundException('No collateral found for this wallet');
    }

    const currentLocked = this.parseAmountToBigInt(collateral.lockedAmount);
    const slashAmount = this.parseAmountToBigInt(amount);
    const actualSlash =
      slashAmount > currentLocked ? currentLocked : slashAmount;

    collateral.lockedAmount = (currentLocked - actualSlash).toString();
    collateral.slashedAmount = (
      this.parseAmountToBigInt(collateral.slashedAmount) + actualSlash
    ).toString();

    await this.collateralRepo.save(collateral);

    return {
      walletAddress,
      amount: actualSlash.toString(),
      poolId,
      remainingLocked: collateral.lockedAmount,
      status: 'slashed',
    };
  }
}
