import { IsString, IsNotEmpty, IsOptional, IsNumber, Min, Max } from 'class-validator';

export class SelectWinnerDto {
  @IsString()
  @IsNotEmpty()
  winner: string; // wallet address of the winner

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
