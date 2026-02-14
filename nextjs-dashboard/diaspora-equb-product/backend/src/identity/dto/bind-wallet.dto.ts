import { IsString, IsNotEmpty, Matches } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class BindWalletDto {
  @ApiProperty({ description: 'Identity hash from Fayda verification', example: '0xabc123...' })
  @IsString()
  @IsNotEmpty()
  @Matches(/^0x[a-fA-F0-9]{64}$/, { message: 'identityHash must be a valid 32-byte hex string' })
  identityHash: string;

  @ApiProperty({ description: 'EVM wallet address', example: '0x1234567890abcdef1234567890abcdef12345678' })
  @IsString()
  @IsNotEmpty()
  @Matches(/^0x[a-fA-F0-9]{40}$/, { message: 'walletAddress must be a valid EVM address' })
  walletAddress: string;
}

export class StoreOnChainDto {
  @ApiProperty({ description: 'Identity hash' })
  @IsString()
  @IsNotEmpty()
  @Matches(/^0x[a-fA-F0-9]{64}$/, { message: 'identityHash must be a valid 32-byte hex string' })
  identityHash: string;

  @ApiProperty({ description: 'EVM wallet address' })
  @IsString()
  @IsNotEmpty()
  @Matches(/^0x[a-fA-F0-9]{40}$/, { message: 'walletAddress must be a valid EVM address' })
  walletAddress: string;
}
