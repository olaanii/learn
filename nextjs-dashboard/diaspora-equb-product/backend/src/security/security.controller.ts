import {
  Controller,
  Get,
  Post,
  Delete,
  Body,
  Param,
  Req,
  UnauthorizedException,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { SecurityService } from './security.service';

@ApiTags('Security')
@ApiBearerAuth()
@Controller('security')
export class SecurityController {
  constructor(private readonly securityService: SecurityService) {}

  private getWallet(req: any): string {
    const wallet: string = req?.user?.walletAddress;
    if (!wallet) throw new UnauthorizedException('Wallet address required');
    return wallet;
  }

  // ─── 2FA ────────────────────────────────────────────────────────

  @Get('2fa/status')
  @ApiOperation({ summary: 'Get 2FA enabled status for authenticated wallet' })
  async get2FAStatus(@Req() req: any) {
    return {
      enabled: await this.securityService.is2FAEnabled(this.getWallet(req)),
    };
  }

  @Post('2fa/setup')
  @ApiOperation({ summary: 'Set up 2FA for authenticated wallet' })
  setup2FA(@Req() req: any) {
    return this.securityService.setup2FA(this.getWallet(req));
  }

  @Post('2fa/verify')
  @ApiOperation({ summary: 'Verify 2FA code and enable 2FA' })
  verify2FA(@Req() req: any, @Body() body: { code: string }) {
    return this.securityService.verify2FA(this.getWallet(req), body.code);
  }

  @Delete('2fa')
  @ApiOperation({ summary: 'Disable and remove 2FA' })
  disable2FA(@Req() req: any) {
    return this.securityService.disable2FA(this.getWallet(req));
  }

  // ─── Devices ──────────────────────────────────────────────────

  @Get('devices')
  @ApiOperation({ summary: 'List trusted devices' })
  listDevices(@Req() req: any) {
    return this.securityService.listDevices(this.getWallet(req));
  }

  @Post('devices/register')
  @ApiOperation({ summary: 'Register or refresh the current trusted device' })
  registerDevice(
    @Req() req: any,
    @Body() body: { fingerprint: string; userAgent?: string },
  ) {
    return this.securityService.registerDevice(
      this.getWallet(req),
      body.fingerprint,
      body.userAgent ?? null,
    );
  }

  @Delete('devices/:id')
  @ApiOperation({ summary: 'Revoke a trusted device' })
  revokeDevice(@Req() req: any, @Param('id') deviceId: string) {
    return this.securityService.revokeDevice(this.getWallet(req), deviceId);
  }

  // ─── Whitelist ────────────────────────────────────────────────

  @Get('whitelist')
  @ApiOperation({ summary: 'List withdrawal whitelist addresses' })
  listWhitelist(@Req() req: any) {
    return this.securityService.listWhitelist(this.getWallet(req));
  }

  @Post('whitelist')
  @ApiOperation({ summary: 'Add address to withdrawal whitelist' })
  addToWhitelist(
    @Req() req: any,
    @Body() body: { address: string; label?: string },
  ) {
    return this.securityService.addToWhitelist(
      this.getWallet(req),
      body.address,
      body.label ?? null,
    );
  }

  @Delete('whitelist/:id')
  @ApiOperation({ summary: 'Remove address from withdrawal whitelist' })
  removeFromWhitelist(@Req() req: any, @Param('id') whitelistId: string) {
    return this.securityService.removeFromWhitelist(this.getWallet(req), whitelistId);
  }
}
