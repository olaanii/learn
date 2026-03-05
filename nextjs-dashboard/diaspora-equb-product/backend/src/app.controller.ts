import { Controller, Get } from '@nestjs/common';
import { Public } from './common/decorators/public.decorator';

/**
 * Root API route so GET /api returns 200 (avoids 404 when checking base URL).
 * For health checks use GET /api/health.
 */
@Controller()
@Public()
export class AppController {
  @Get()
  root() {
    return {
      status: 'ok',
      message: 'Diaspora Equb API',
      health: '/api/health',
    };
  }
}
