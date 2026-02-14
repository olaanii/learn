import { Body, Controller, Post } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger';
import { AuthService } from './auth.service';
import { VerifyFaydaDto } from './dto/verify-fayda.dto';
import { Public } from '../common/decorators/public.decorator';

@ApiTags('Authentication')
@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('fayda/verify')
  @Public()
  @ApiOperation({ summary: 'Verify Fayda e-ID and receive JWT' })
  @ApiResponse({ status: 201, description: 'Verification successful, JWT returned' })
  @ApiResponse({ status: 401, description: 'Invalid Fayda token' })
  verifyFayda(@Body() dto: VerifyFaydaDto) {
    return this.authService.verifyFayda(dto.token);
  }

  @Post('dev-login')
  @Public()
  @ApiOperation({
    summary: 'Dev-only login: generates JWT for testing without Fayda (development only)',
  })
  @ApiResponse({ status: 201, description: 'Dev JWT returned' })
  devLogin(@Body() body: { walletAddress?: string }) {
    return this.authService.devLogin(body.walletAddress);
  }
}
