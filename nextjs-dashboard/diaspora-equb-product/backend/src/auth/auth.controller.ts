import { Body, Controller, Post } from '@nestjs/common';
import { AuthService } from './auth.service';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('fayda/verify')
  verifyFayda(@Body() body: { token: string }) {
    return this.authService.verifyFayda(body.token);
  }
}
