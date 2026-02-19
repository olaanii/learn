import { IsString, IsNotEmpty, Matches } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class WalletChallengeDto {
  @ApiProperty({ description: 'EVM wallet address', example: '0x1234567890abcdef1234567890abcdef12345678' })
  @IsString()
  @IsNotEmpty()
  @Matches(/^0x[a-fA-F0-9]{40}$/, { message: 'Invalid EVM wallet address' })
  walletAddress: string;
}
