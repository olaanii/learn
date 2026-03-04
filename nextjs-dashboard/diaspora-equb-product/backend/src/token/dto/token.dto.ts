import {
  IsString,
  IsNotEmpty,
  Matches,
  IsOptional,
  IsNumber,
  Min,
  Max,
  IsIn,
  IsInt,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class GetTransactionsQueryDto {
  @ApiProperty({ description: 'EVM wallet address' })
  @IsString()
  @IsNotEmpty()
  @Matches(/^0x[a-fA-F0-9]{40}$/, { message: 'walletAddress must be a valid EVM address' })
  walletAddress: string;

  @ApiPropertyOptional({ description: 'Token symbol (USDC, USDT, CTC, tCTC, ALL)', example: 'USDC', default: 'USDC' })
  @IsOptional()
  @IsString()
  token?: string;

  @ApiPropertyOptional({ description: 'Max transactions to return', example: 50, default: 50 })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(200)
  limit?: number;

  @ApiPropertyOptional({ description: 'Lower bound timestamp in milliseconds since epoch (inclusive)' })
  @IsOptional()
  @IsInt()
  fromTimestamp?: number;

  @ApiPropertyOptional({ description: 'Upper bound timestamp in milliseconds since epoch (inclusive)' })
  @IsOptional()
  @IsInt()
  toTimestamp?: number;

  @ApiPropertyOptional({ description: 'Direction filter', enum: ['sent', 'received'] })
  @IsOptional()
  @IsString()
  @IsIn(['sent', 'received'])
  direction?: 'sent' | 'received';

  @ApiPropertyOptional({ description: 'Status filter', enum: ['success', 'failed'] })
  @IsOptional()
  @IsString()
  @IsIn(['success', 'failed'])
  status?: 'success' | 'failed';

  @ApiPropertyOptional({ description: 'Pagination cursor (reserved for future paging)' })
  @IsOptional()
  @IsString()
  cursor?: string;
}

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

export class PortfolioQueryDto {
  @ApiProperty({ description: 'EVM wallet address' })
  @IsString()
  @IsNotEmpty()
  @Matches(/^0x[a-fA-F0-9]{40}$/, { message: 'wallet must be a valid EVM address' })
  wallet: string;
}
