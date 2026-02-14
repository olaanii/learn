import {
  Injectable,
  Logger,
  ConflictException,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Identity } from '../entities/identity.entity';
import { Web3Service } from '../web3/web3.service';

@Injectable()
export class IdentityService {
  private readonly logger = new Logger(IdentityService.name);

  constructor(
    @InjectRepository(Identity)
    private readonly identityRepo: Repository<Identity>,
    private readonly web3Service: Web3Service,
  ) {}

  async bindWallet(identityHash: string, walletAddress: string) {
    this.logger.log(`Binding wallet ${walletAddress} to identity ${identityHash}`);

    // Check if wallet is already bound to another identity
    const existingByWallet = await this.identityRepo.findOne({
      where: { walletAddress },
    });
    if (existingByWallet && existingByWallet.identityHash !== identityHash) {
      throw new ConflictException('Wallet is already bound to another identity');
    }

    // Check if identity is already bound to another wallet
    const existingByHash = await this.identityRepo.findOne({
      where: { identityHash },
    });
    if (!existingByHash) {
      throw new NotFoundException('Identity not found. Verify with Fayda first.');
    }
    if (existingByHash.walletAddress && existingByHash.walletAddress !== walletAddress) {
      throw new ConflictException('Identity is already bound to another wallet');
    }

    // Update the identity record
    existingByHash.walletAddress = walletAddress;
    existingByHash.bindingStatus = 'bound';
    await this.identityRepo.save(existingByHash);

    this.logger.log(`Wallet ${walletAddress} bound to identity ${identityHash}`);

    return {
      identityHash,
      walletAddress,
      status: 'bound',
    };
  }

  async storeOnChain(identityHash: string, walletAddress: string) {
    this.logger.log(`Queuing on-chain identity storage for ${walletAddress}`);

    const identity = await this.identityRepo.findOne({
      where: { identityHash },
    });
    if (!identity) {
      throw new NotFoundException('Identity not found');
    }
    if (identity.walletAddress !== walletAddress) {
      throw new ConflictException('Wallet does not match bound identity');
    }

    // In a full implementation, this would call the IdentityRegistry contract:
    // const contract = this.web3Service.getIdentityRegistry();
    // const tx = await contract.bindIdentity(walletAddress, identityHash);
    // await tx.wait();

    identity.bindingStatus = 'queued-for-onchain';
    await this.identityRepo.save(identity);

    return {
      identityHash,
      walletAddress,
      status: 'queued-for-onchain',
      registryContract: 'IdentityRegistry',
    };
  }

  async findByWallet(walletAddress: string): Promise<Identity | null> {
    return this.identityRepo.findOne({ where: { walletAddress } });
  }

  async findByHash(identityHash: string): Promise<Identity | null> {
    return this.identityRepo.findOne({ where: { identityHash } });
  }
}
