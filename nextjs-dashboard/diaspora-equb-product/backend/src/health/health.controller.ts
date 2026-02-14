import { Controller, Get } from '@nestjs/common';
import {
  HealthCheck,
  HealthCheckService,
  TypeOrmHealthIndicator,
} from '@nestjs/terminus';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { Web3Service } from '../web3/web3.service';
import { Public } from '../common/decorators/public.decorator';

@ApiTags('Health')
@Controller('health')
@Public()
export class HealthController {
  constructor(
    private health: HealthCheckService,
    private db: TypeOrmHealthIndicator,
    private web3: Web3Service,
  ) {}

  @Get()
  @HealthCheck()
  @ApiOperation({ summary: 'Application health check' })
  check() {
    return this.health.check([
      () => this.db.pingCheck('database'),
      async () => {
        const healthy = await this.web3.isRpcHealthy();
        if (healthy) {
          return { rpc: { status: 'up' } };
        }
        throw new Error('RPC node unreachable');
      },
    ]);
  }
}
