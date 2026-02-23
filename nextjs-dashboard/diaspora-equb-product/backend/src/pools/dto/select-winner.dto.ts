import {
  IsString,
  IsNotEmpty,
  IsOptional,
  IsNumber,
  Min,
  Max,
  IsIn,
} from 'class-validator';

export class SelectWinnerDto {
  @IsOptional()
  @IsString()
  @IsIn(['auto', 'close', 'schedule'])
  phase?: 'auto' | 'close' | 'schedule';

  @IsString()
  @IsOptional()
  winner?: string; // optional override; must match rotating winner if provided

  @IsString()
  @IsNotEmpty()
  total: string; // total payout amount (as string with wei/ctc precision)

  @IsNumber()
  @Min(0)
  @Max(100)
  upfrontPercent: number; // percent paid upfront (0-100)

  @IsNumber()
  @Min(1)
  totalRounds: number; // number of rounds for payout stream

  @IsString()
  @IsOptional()
  caller?: string; // address of caller (creator) — validated against pool.createdBy
}
