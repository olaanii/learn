import { IsString, Length } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class ApplyReferralDto {
  @ApiProperty({ example: 'Ab3kZ9xQ', description: 'Referral code to apply' })
  @IsString()
  @Length(8, 12)
  code: string;
}
