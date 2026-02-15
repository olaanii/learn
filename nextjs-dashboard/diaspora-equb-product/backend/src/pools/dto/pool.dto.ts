import {
  IsString,
  IsNotEmpty,
  IsNumber,
  IsPositive,
  IsOptional,
  Min,
  Max,
  Matches,
  IsUUID,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreatePoolDto {
  @ApiProperty({ description: 'Pool tier (0-3)', example: 0, minimum: 0, maximum: 3 })
  @IsNumber()
  @Min(0)
  @Max(3)
  tier: number;

  @ApiProperty({ description: 'Contribution amount in wei (as string)', example: '1000000000000000000' })
  @IsString()
  @IsNotEmpty()
  contributionAmount: string;

  @ApiProperty({ description: 'Maximum number of pool members', example: 10, minimum: 2, maximum: 50 })
  @IsNumber()
  @Min(2)
  @Max(50)
  maxMembers: number;

  @ApiProperty({ description: 'Treasury wallet address', example: '0x1234...' })
  @IsString()
  @IsNotEmpty()
  @Matches(/^0x[a-fA-F0-9]{40}$/, { message: 'treasury must be a valid EVM address' })
  treasury: string;

  @ApiPropertyOptional({
    description: 'ERC-20 token address for contributions. Omit or pass zero address for native CTC.',
    example: '0x0000000000000000000000000000000000000000',
  })
  @IsOptional()
  @IsString()
  @Matches(/^0x[a-fA-F0-9]{40}$/, { message: 'token must be a valid EVM address' })
  token?: string;
}

export class JoinPoolDto {
  @ApiProperty({ description: 'Pool ID' })
  @IsUUID()
  poolId: string;

  @ApiProperty({ description: 'Wallet address joining the pool' })
  @IsString()
  @IsNotEmpty()
  @Matches(/^0x[a-fA-F0-9]{40}$/, { message: 'walletAddress must be a valid EVM address' })
  walletAddress: string;
}

export class RecordContributionDto {
  @ApiProperty({ description: 'Pool ID' })
  @IsUUID()
  poolId: string;

  @ApiProperty({ description: 'Contributor wallet address' })
  @IsString()
  @IsNotEmpty()
  @Matches(/^0x[a-fA-F0-9]{40}$/, { message: 'walletAddress must be a valid EVM address' })
  walletAddress: string;

  @ApiProperty({ description: 'Round number', example: 1, minimum: 1 })
  @IsNumber()
  @IsPositive()
  round: number;
}

export class CloseRoundDto {
  @ApiProperty({ description: 'Pool ID' })
  @IsUUID()
  poolId: string;

  @ApiProperty({ description: 'Round number to close', example: 1 })
  @IsNumber()
  @IsPositive()
  round: number;
}

export class ScheduleStreamDto {
  @ApiProperty({ description: 'Pool ID' })
  @IsUUID()
  poolId: string;

  @ApiProperty({ description: 'Beneficiary wallet address' })
  @IsString()
  @IsNotEmpty()
  @Matches(/^0x[a-fA-F0-9]{40}$/, { message: 'beneficiary must be a valid EVM address' })
  beneficiary: string;

  @ApiProperty({ description: 'Total payout amount in wei (as string)', example: '10000000000000000000' })
  @IsString()
  @IsNotEmpty()
  total: string;

  @ApiProperty({ description: 'Upfront payout percentage (0-30)', example: 20, minimum: 0, maximum: 30 })
  @IsNumber()
  @Min(0)
  @Max(30)
  upfrontPercent: number;

  @ApiProperty({ description: 'Number of rounds for streamed payout', example: 8 })
  @IsNumber()
  @IsPositive()
  totalRounds: number;
}
