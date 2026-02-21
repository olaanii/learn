import { IsString, IsNotEmpty } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class VerifyFaydaDto {
  @ApiProperty({ description: 'Fayda e-ID verification token', example: 'fayda-token-abc123' })
  @IsString()
  @IsNotEmpty()
  token: string;
}
