import {
  IsNumber,
  IsOptional,
  Min,
  Max,
  IsUUID,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

/** EqubType: 0=Finance, 1=House, 2=Car, 3=Travel, 4=Special, 5=Workplace, 6=Education, 7=Wedding, 8=Emergency */
const EQUB_TYPE_DESC = 'Equb type (0-8): Finance=0, House=1, Car=2, Travel=3, Special=4, Workplace=5, Education=6, Wedding=7, Emergency=8';
/** Frequency: 0=Daily, 1=Weekly, 2=BiWeekly, 3=Monthly */
const FREQUENCY_DESC = 'Contribution frequency (0-3): Daily=0, Weekly=1, BiWeekly=2, Monthly=3';
/** PayoutMethod: 0=Lottery, 1=Rotation, 2=Bid */
const PAYOUT_DESC = 'Payout method (0-2): Lottery=0, Rotation=1, Bid=2';

export class CreateEqubRulesDto {
  @ApiProperty({ description: EQUB_TYPE_DESC, example: 0, minimum: 0, maximum: 8 })
  @IsNumber()
  @Min(0)
  @Max(8)
  equbType: number;

  @ApiProperty({ description: FREQUENCY_DESC, example: 1, minimum: 0, maximum: 3 })
  @IsNumber()
  @Min(0)
  @Max(3)
  frequency: number;

  @ApiProperty({ description: PAYOUT_DESC, example: 0, minimum: 0, maximum: 2 })
  @IsNumber()
  @Min(0)
  @Max(2)
  payoutMethod: number;

  @ApiPropertyOptional({ description: 'Grace period before default (seconds)', example: 604800, default: 604800 })
  @IsOptional()
  @IsNumber()
  @Min(0)
  gracePeriodSeconds?: number;

  @ApiPropertyOptional({ description: 'Penalty severity (credit score deduction)', example: 10, default: 10 })
  @IsOptional()
  @IsNumber()
  @Min(0)
  penaltySeverity?: number;

  @ApiPropertyOptional({ description: 'Round duration (seconds)', example: 2592000, default: 2592000 })
  @IsOptional()
  @IsNumber()
  @Min(0)
  roundDurationSeconds?: number;

  @ApiPropertyOptional({ description: 'Late fee percentage', example: 0, minimum: 0, maximum: 100 })
  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(100)
  lateFeePercent?: number;
}

export class UpdateEqubRulesDto {
  @ApiPropertyOptional({ description: EQUB_TYPE_DESC })
  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(8)
  equbType?: number;

  @ApiPropertyOptional({ description: FREQUENCY_DESC })
  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(3)
  frequency?: number;

  @ApiPropertyOptional({ description: PAYOUT_DESC })
  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(2)
  payoutMethod?: number;

  @ApiPropertyOptional({ description: 'Grace period before default (seconds)' })
  @IsOptional()
  @IsNumber()
  @Min(0)
  gracePeriodSeconds?: number;

  @ApiPropertyOptional({ description: 'Penalty severity' })
  @IsOptional()
  @IsNumber()
  @Min(0)
  penaltySeverity?: number;

  @ApiPropertyOptional({ description: 'Round duration (seconds)' })
  @IsOptional()
  @IsNumber()
  @Min(0)
  roundDurationSeconds?: number;

  @ApiPropertyOptional({ description: 'Late fee percentage', minimum: 0, maximum: 100 })
  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(100)
  lateFeePercent?: number;
}
