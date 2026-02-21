import { IsString, IsNotEmpty, Matches, IsOptional, IsNumber, Min, Max } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class FaucetDto {
  @ApiProperty({ description: 'Wallet address to receive test tokens' })
  @IsString()
  @IsNotEmpty()
  @Matches(/^0x[a-fA-F0-9]{40}$/, { message: 'walletAddress must be a valid EVM address' })
  walletAddress: string;

  @ApiPropertyOptional({ description: 'Amount of tokens to mint (max 10,000)', example: 1000, default: 1000 })
  @IsOptional()
  @IsNumber()
  @Min(1)
  @Max(10000)
  amount?: number;

  @ApiPropertyOptional({ description: 'Token symbol (USDC or USDT)', example: 'USDC' })
  @IsOptional()
  @IsString()
  token?: string;
}

export class TransferDto {
  @ApiProperty({ description: 'Sender wallet address' })
  @IsString()
  @IsNotEmpty()
  @Matches(/^0x[a-fA-F0-9]{40}$/, { message: 'from must be a valid EVM address' })
  from: string;

  @ApiProperty({ description: 'Recipient wallet address' })
  @IsString()
  @IsNotEmpty()
  @Matches(/^0x[a-fA-F0-9]{40}$/, { message: 'to must be a valid EVM address' })
  to: string;

  @ApiProperty({ description: 'Amount in token decimals (as string)', example: '1000000' })
  @IsString()
  @IsNotEmpty()
  amount: string;

  @ApiPropertyOptional({ description: 'Token symbol (USDC or USDT)', example: 'USDC' })
  @IsOptional()
  @IsString()
  token?: string;
}

export class WithdrawDto {
  @ApiProperty({ description: 'Sender wallet address' })
  @IsString()
  @IsNotEmpty()
  @Matches(/^0x[a-fA-F0-9]{40}$/, { message: 'from must be a valid EVM address' })
  from: string;

  @ApiProperty({ description: 'Destination wallet/account address' })
  @IsString()
  @IsNotEmpty()
  @Matches(/^0x[a-fA-F0-9]{40}$/, { message: 'to must be a valid EVM address' })
  to: string;

  @ApiProperty({ description: 'Amount in token decimals (as string)', example: '1000000' })
  @IsString()
  @IsNotEmpty()
  amount: string;

  @ApiPropertyOptional({ description: 'Token symbol (USDC or USDT)', example: 'USDC' })
  @IsOptional()
  @IsString()
  token?: string;

  @ApiPropertyOptional({ description: 'Network (ERC-20, BEP-20)', example: 'ERC-20' })
  @IsOptional()
  @IsString()
  network?: string;
}
