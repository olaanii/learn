import {
  Injectable,
  Logger,
  ConflictException,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ethers } from 'ethers';
import { Identity } from '../entities/identity.entity';
import { Web3Service, UnsignedTxDto } from '../web3/web3.service';

@Injectable()
export class IdentityService {
  private readonly logger = new Logger(IdentityService.name);

  constructor(
    @InjectRepository(Identity)
    private readonly identityRepo: Repository<Identity>,
    private readonly web3Service: Web3Service,
  ) {}

  async bindWallet(identityHash: string, walletAddress: string) {
    this.logger.log(
      `Binding wallet ${walletAddress} to identity ${identityHash}`,
    );

    // Check if wallet is already bound to another identity
    const existingByWallet = await this.identityRepo.findOne({
      where: { walletAddress },
    });
    if (existingByWallet && existingByWallet.identityHash !== identityHash) {
      throw new ConflictException(
        'Wallet is already bound to another identity',
      );
    }

    // Check if identity is already bound to another wallet
    const existingByHash = await this.identityRepo.findOne({
      where: { identityHash },
    });
    if (!existingByHash) {
      throw new NotFoundException(
        'Identity not found. Verify with Fayda first.',
      );
    }
    if (
      existingByHash.walletAddress &&
      existingByHash.walletAddress !== walletAddress
    ) {
      throw new ConflictException(
        'Identity is already bound to another wallet',
      );
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

  /**
   * Build unsigned TX to bind an identity on-chain via IdentityRegistry.
   * The user signs this TX with their wallet to commit the binding to the blockchain.
   */
  async buildStoreOnChain(
    identityHash: string,
    walletAddress: string,
  ): Promise<UnsignedTxDto> {
    this.logger.log(
      `Building on-chain identity binding TX for ${walletAddress}`,
    );

    const identity = await this.identityRepo.findOne({
      where: { identityHash },
    });
    if (!identity) {
      throw new NotFoundException('Identity not found');
    }
    if (identity.walletAddress !== walletAddress) {
      throw new ConflictException('Wallet does not match bound identity');
    }

    // Encode calldata: identityRegistry.bindIdentity(wallet, identityHash)
    // identityHash must be bytes32 on-chain
    const identityRegistry = this.web3Service.getIdentityRegistry();
    const hashBytes32 = ethers.zeroPadValue(identityHash, 32);
    const data = identityRegistry.interface.encodeFunctionData(
      'bindIdentity',
      [walletAddress, hashBytes32],
    );
    const to = await identityRegistry.getAddress();

    return this.web3Service.buildUnsignedTx(to, data, '0', '150000');
  }

  /**
   * Legacy: queue identity for on-chain storage (DB-only, kept for dev/test).
   */
  async storeOnChain(identityHash: string, walletAddress: string) {
    this.logger.log(
      `Queuing on-chain identity storage for ${walletAddress}`,
    );

    const identity = await this.identityRepo.findOne({
      where: { identityHash },
    });
    if (!identity) {
      throw new NotFoundException('Identity not found');
    }
    if (identity.walletAddress !== walletAddress) {
      throw new ConflictException('Wallet does not match bound identity');
    }

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
