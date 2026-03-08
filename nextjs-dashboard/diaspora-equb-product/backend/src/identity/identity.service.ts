import {
  Injectable,
  Logger,
  ConflictException,
  NotFoundException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ethers } from 'ethers';
import { Identity } from '../entities/identity.entity';
import { Web3Service, UnsignedTxDto } from '../web3/web3.service';
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class IdentityService {
  private readonly logger = new Logger(IdentityService.name);

  constructor(
    @InjectRepository(Identity)
    private readonly identityRepo: Repository<Identity>,
    private readonly web3Service: Web3Service,
    private readonly notifications: NotificationsService,
    private readonly jwtService: JwtService,
  ) {}

  async bindWallet(
    identityHash: string,
    walletAddress: string,
    sessionContext?: {
      firebaseUid?: string;
      email?: string;
      displayName?: string;
    },
  ) {
    const normalizedWalletAddress = walletAddress.toLowerCase();
    this.logger.log(
      `Binding wallet ${normalizedWalletAddress} to identity ${identityHash}`,
    );

    // Check if wallet is already bound to another identity
    const existingByWallet = await this.identityRepo.findOne({
      where: { walletAddress: normalizedWalletAddress },
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
      existingByHash.walletAddress.toLowerCase() !== normalizedWalletAddress
    ) {
      throw new ConflictException(
        'Identity is already bound to another wallet',
      );
    }

    // Update the identity record
    existingByHash.walletAddress = normalizedWalletAddress;
    existingByHash.bindingStatus = 'bound';
    await this.identityRepo.save(existingByHash);

    const accessToken = this.jwtService.sign({
      sub: identityHash,
      walletAddress: normalizedWalletAddress,
      firebaseUid: sessionContext?.firebaseUid,
      email: sessionContext?.email,
      displayName: sessionContext?.displayName,
    });

    this.notifications
      .create(
        normalizedWalletAddress,
        'wallet_bound',
        'Wallet Bound',
        'Your wallet has been successfully bound to your verified identity.',
        {
          identityHash,
          walletAddress: normalizedWalletAddress,
          idempotencyKey: `wallet_bound:${normalizedWalletAddress}:${identityHash.toLowerCase()}`,
        },
      )
      .catch((error) => {
        this.logger.warn(`Failed to emit wallet_bound notification: ${error?.message ?? error}`);
      });

    this.logger.log(
      `Wallet ${normalizedWalletAddress} bound to identity ${identityHash}`,
    );

    return {
      identityHash,
      walletAddress: normalizedWalletAddress,
      status: 'bound',
      accessToken,
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
    if (identity.walletAddress?.toLowerCase() !== walletAddress.toLowerCase()) {
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
    if (identity.walletAddress?.toLowerCase() !== walletAddress.toLowerCase()) {
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
