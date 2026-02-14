import {
  Injectable,
  Logger,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Collateral } from '../entities/collateral.entity';
import { Web3Service } from '../web3/web3.service';

@Injectable()
export class CollateralService {
  private readonly logger = new Logger(CollateralService.name);

  constructor(
    @InjectRepository(Collateral)
    private readonly collateralRepo: Repository<Collateral>,
    private readonly web3Service: Web3Service,
  ) {}

  async lock(walletAddress: string, amount: string, poolId?: string) {
    this.logger.log(`Locking collateral: wallet=${walletAddress}, amount=${amount}`);

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

    const currentLocked = BigInt(collateral.lockedAmount);
    const lockAmount = BigInt(amount);
    collateral.lockedAmount = (currentLocked + lockAmount).toString();

    await this.collateralRepo.save(collateral);

    // In production: call CollateralVault.lockCollateral on-chain
    // const contract = this.web3Service.getCollateralVault();
    // const tx = await contract.lockCollateral(walletAddress, amount);

    return {
      walletAddress,
      amount,
      poolId,
      lockedAmount: collateral.lockedAmount,
      status: 'locked',
    };
  }

  async slash(walletAddress: string, amount: string, poolId?: string) {
    this.logger.log(`Slashing collateral: wallet=${walletAddress}, amount=${amount}`);

    const collateral = await this.collateralRepo.findOne({
      where: { walletAddress, poolId: poolId || undefined },
    });

    if (!collateral) {
      throw new NotFoundException('No collateral found for this wallet');
    }

    const currentLocked = BigInt(collateral.lockedAmount);
    const slashAmount = BigInt(amount);
    const actualSlash = slashAmount > currentLocked ? currentLocked : slashAmount;

    collateral.lockedAmount = (currentLocked - actualSlash).toString();
    collateral.slashedAmount = (BigInt(collateral.slashedAmount) + actualSlash).toString();

    await this.collateralRepo.save(collateral);

    // In production: call CollateralVault.slashCollateral on-chain

    return {
      walletAddress,
      amount: actualSlash.toString(),
      poolId,
      remainingLocked: collateral.lockedAmount,
      status: 'slashed',
    };
  }

  async getCollateral(walletAddress: string) {
    const collaterals = await this.collateralRepo.find({
      where: { walletAddress },
    });
    return collaterals;
  }
}
