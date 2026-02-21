import { IsString, IsNotEmpty, IsNumber, IsOptional, Matches } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class UpdateCreditDto {
  @ApiProperty({ description: 'Wallet address' })
  @IsString()
  @IsNotEmpty()
  @Matches(/^0x[a-fA-F0-9]{40}$/, { message: 'walletAddress must be a valid EVM address' })
  walletAddress: string;

  @ApiProperty({ description: 'Score delta (positive or negative)', example: 1 })
  @IsNumber()
  delta: number;

  @ApiPropertyOptional({ description: 'Reason for the score update', example: 'round-completion' })
  @IsOptional()
  @IsString()
  reason?: string;
}
