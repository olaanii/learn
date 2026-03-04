import { Injectable, BadRequestException, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as crypto from 'crypto';

import { TotpSecret } from '../entities/totp-secret.entity';
import { Device } from '../entities/device.entity';
import { WithdrawalWhitelist } from '../entities/withdrawal-whitelist.entity';

const BASE32_CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

function encodeBase32(buffer: Buffer): string {
  let bits = 0;
  let value = 0;
  let result = '';
  for (const byte of buffer) {
    value = (value << 8) | byte;
    bits += 8;
    while (bits >= 5) {
      bits -= 5;
      result += BASE32_CHARS[(value >>> bits) & 0x1f];
    }
  }
  if (bits > 0) {
    result += BASE32_CHARS[(value << (5 - bits)) & 0x1f];
  }
  return result;
}

function decodeBase32(encoded: string): Buffer {
  const cleaned = encoded.replace(/=+$/, '').toUpperCase();
  let bits = 0;
  let value = 0;
  const bytes: number[] = [];
  for (const ch of cleaned) {
    const idx = BASE32_CHARS.indexOf(ch);
    if (idx === -1) continue;
    value = (value << 5) | idx;
    bits += 5;
    if (bits >= 8) {
      bits -= 8;
      bytes.push((value >>> bits) & 0xff);
    }
  }
  return Buffer.from(bytes);
}

function generateTotpCode(secret: Buffer, timeStep: number): string {
  const timeBuffer = Buffer.alloc(8);
  timeBuffer.writeUInt32BE(0, 0);
  timeBuffer.writeUInt32BE(timeStep, 4);

  const hmac = crypto.createHmac('sha1', secret).update(timeBuffer).digest();
  const offset = hmac[hmac.length - 1] & 0x0f;
  const code =
    ((hmac[offset] & 0x7f) << 24) |
    ((hmac[offset + 1] & 0xff) << 16) |
    ((hmac[offset + 2] & 0xff) << 8) |
    (hmac[offset + 3] & 0xff);

  return String(code % 1_000_000).padStart(6, '0');
}

@Injectable()
export class SecurityService {
  constructor(
    @InjectRepository(TotpSecret)
    private readonly totpRepo: Repository<TotpSecret>,
    @InjectRepository(Device)
    private readonly deviceRepo: Repository<Device>,
    @InjectRepository(WithdrawalWhitelist)
    private readonly whitelistRepo: Repository<WithdrawalWhitelist>,
  ) {}

  // ─── 2FA (TOTP) ───────────────────────────────────────────────────

  async setup2FA(walletAddress: string) {
    const existing = await this.totpRepo.findOne({ where: { walletAddress } });
    if (existing?.enabled) {
      throw new BadRequestException('2FA is already enabled');
    }

    const secretBytes = crypto.randomBytes(20);
    const secret = encodeBase32(secretBytes);
    const qrUri =
      `otpauth://totp/DiasporaEqub:${walletAddress}` +
      `?secret=${secret}&issuer=DiasporaEqub&algorithm=SHA1&digits=6&period=30`;

    if (existing) {
      existing.encryptedSecret = secret;
      existing.enabled = false;
      existing.verifiedAt = null;
      await this.totpRepo.save(existing);
    } else {
      await this.totpRepo.save(
        this.totpRepo.create({ walletAddress, encryptedSecret: secret, enabled: false }),
      );
    }

    return { secret, qrUri };
  }

  async verify2FA(walletAddress: string, code: string) {
    const record = await this.totpRepo.findOne({ where: { walletAddress } });
    if (!record) {
      throw new NotFoundException('2FA has not been set up');
    }

    const secretBuf = decodeBase32(record.encryptedSecret);
    const now = Math.floor(Date.now() / 1000);
    const currentStep = Math.floor(now / 30);

    const valid = [currentStep - 1, currentStep, currentStep + 1].some(
      (step) => generateTotpCode(secretBuf, step) === code,
    );

    if (!valid) {
      throw new BadRequestException('Invalid 2FA code');
    }

    record.enabled = true;
    record.verifiedAt = new Date();
    await this.totpRepo.save(record);
    return { success: true };
  }

  async disable2FA(walletAddress: string) {
    const result = await this.totpRepo.delete({ walletAddress });
    if (result.affected === 0) {
      throw new NotFoundException('2FA is not configured');
    }
    return { success: true };
  }

  async is2FAEnabled(walletAddress: string): Promise<boolean> {
    const record = await this.totpRepo.findOne({ where: { walletAddress } });
    return !!record?.enabled;
  }

  // ─── Devices ──────────────────────────────────────────────────────

  async listDevices(walletAddress: string) {
    return this.deviceRepo.find({
      where: { walletAddress },
      order: { lastSeen: 'DESC' },
    });
  }

  async registerDevice(walletAddress: string, fingerprint: string, userAgent: string | null) {
    let device = await this.deviceRepo.findOne({ where: { walletAddress, fingerprint } });
    if (device) {
      device.lastSeen = new Date();
      if (userAgent !== null) device.userAgent = userAgent;
      return this.deviceRepo.save(device);
    }
    device = this.deviceRepo.create({
      walletAddress,
      fingerprint,
      userAgent,
      trusted: true,
      lastSeen: new Date(),
    });
    return this.deviceRepo.save(device);
  }

  async revokeDevice(walletAddress: string, deviceId: string) {
    const result = await this.deviceRepo.delete({ id: deviceId, walletAddress });
    if (result.affected === 0) {
      throw new NotFoundException('Device not found');
    }
    return { success: true };
  }

  // ─── Withdrawal Whitelist ─────────────────────────────────────────

  async listWhitelist(walletAddress: string) {
    return this.whitelistRepo.find({
      where: { walletAddress },
      order: { addedAt: 'DESC' },
    });
  }

  async addToWhitelist(walletAddress: string, address: string, label: string | null) {
    const entry = this.whitelistRepo.create({
      walletAddress,
      whitelistedAddress: address,
      label,
    });
    return this.whitelistRepo.save(entry);
  }

  async removeFromWhitelist(walletAddress: string, whitelistId: string) {
    const result = await this.whitelistRepo.delete({ id: whitelistId, walletAddress });
    if (result.affected === 0) {
      throw new NotFoundException('Whitelist entry not found');
    }
    return { success: true };
  }
}
