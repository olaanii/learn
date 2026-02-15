import {
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Collateral } from '../entities/collateral.entity';
import { Web3Service, UnsignedTxDto } from '../web3/web3.service';

@Injectable()
export class CollateralService {
  private readonly logger = new Logger(CollateralService.name);

  constructor(
    @InjectRepository(Collateral)
    private readonly collateralRepo: Repository<Collateral>,
    private readonly web3Service: Web3Service,
  ) {}

  // ─── TX Builder Methods ─────────────────────────────────────────────────────

  /**
   * Build unsigned TX to deposit collateral into CollateralVault.
   * The `amount` is sent as msg.value (native CTC).
   */
  async buildDeposit(amount: string): Promise<UnsignedTxDto> {
    this.logger.log(`Building depositCollateral TX: amount=${amount}`);

    const collateralVault = this.web3Service.getCollateralVault();
    const data =
      collateralVault.interface.encodeFunctionData('depositCollateral');
    const to = await collateralVault.getAddress();

    return this.web3Service.buildUnsignedTx(to, data, amount, '100000');
  }

  /**
   * Build unsigned TX to release collateral back to the user.
   */
  async buildRelease(
    userAddress: string,
    amount: string,
  ): Promise<UnsignedTxDto> {
    this.logger.log(
      `Building releaseCollateral TX: user=${userAddress}, amount=${amount}`,
    );

    const collateralVault = this.web3Service.getCollateralVault();
    const data = collateralVault.interface.encodeFunctionData(
      'releaseCollateral',
      [userAddress, amount],
    );
    const to = await collateralVault.getAddress();

    return this.web3Service.buildUnsignedTx(to, data, '0', '100000');
  }

  // ─── On-Chain Read Methods ──────────────────────────────────────────────────

  /**
   * Read collateral balance from on-chain CollateralVault.
   * Falls back to DB cache on error.
   */
  async getCollateral(walletAddress: string) {
    // Try on-chain read first
    try {
      const collateralVault = this.web3Service.getCollateralVault();
      const onChainBalance: bigint =
        await collateralVault.collateralOf(walletAddress);
      const onChainLocked: bigint =
        await collateralVault.lockedOf(walletAddress);

      return [
        {
          walletAddress,
          lockedAmount: onChainLocked.toString(),
          availableBalance: onChainBalance.toString(),
          slashedAmount: '0', // on-chain vault doesn't track cumulative slashed
          source: 'on-chain',
        },
      ];
    } catch (e) {
      this.logger.warn(
        `On-chain collateral read failed, falling back to DB: ${e.message}`,
      );
    }

    // Fall back to DB cache
    const collaterals = await this.collateralRepo.find({
      where: { walletAddress },
    });
    return collaterals;
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
