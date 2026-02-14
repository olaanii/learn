import { IsString, IsNotEmpty, Matches, IsOptional, IsUUID } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class LockCollateralDto {
  @ApiProperty({ description: 'Wallet address' })
  @IsString()
  @IsNotEmpty()
  @Matches(/^0x[a-fA-F0-9]{40}$/, { message: 'walletAddress must be a valid EVM address' })
  walletAddress: string;

  @ApiProperty({ description: 'Amount to lock in wei (as string)', example: '500000000000000000' })
  @IsString()
  @IsNotEmpty()
  amount: string;

  @ApiPropertyOptional({ description: 'Associated pool ID' })
  @IsOptional()
  @IsUUID()
  poolId?: string;
}

export class SlashCollateralDto {
  @ApiProperty({ description: 'Wallet address' })
  @IsString()
  @IsNotEmpty()
  @Matches(/^0x[a-fA-F0-9]{40}$/, { message: 'walletAddress must be a valid EVM address' })
  walletAddress: string;

  @ApiProperty({ description: 'Amount to slash in wei (as string)', example: '500000000000000000' })
  @IsString()
  @IsNotEmpty()
  amount: string;

  @ApiPropertyOptional({ description: 'Associated pool ID' })
  @IsOptional()
  @IsUUID()
  poolId?: string;
}
