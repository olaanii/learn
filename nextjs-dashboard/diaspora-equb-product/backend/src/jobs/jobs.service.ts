import {
  Injectable,
  Logger,
  OnModuleInit,
  OnModuleDestroy,
} from '@nestjs/common';

/**
 * Lightweight scheduled-job runner using setInterval.
 * Migrate to BullMQ repeatable jobs once the ioredis / @nestjs/bullmq
 * packages are installed and a Redis connection is available.
 */
@Injectable()
export class JobsService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(JobsService.name);
  private intervals: ReturnType<typeof setInterval>[] = [];

  onModuleInit() {
    this.logger.log('JobsService started (interval-based, BullMQ-ready)');

    this.intervals.push(
      setInterval(() => this.computeHealthScores(), 3_600_000),
    );

    this.intervals.push(
      setInterval(() => this.snapshotPlatformStats(), 21_600_000),
    );
  }

  onModuleDestroy() {
    this.intervals.forEach((i) => clearInterval(i));
    this.intervals = [];
    this.logger.log('JobsService stopped');
  }

  private async computeHealthScores() {
    this.logger.log('Job: computeHealthScores (placeholder)');
    // TODO: inject AnalyticsService and recompute per-pool health scores
  }

  private async snapshotPlatformStats() {
    this.logger.log('Job: snapshotPlatformStats (placeholder)');
    // TODO: aggregate and persist platform-wide stats for dashboard
  }
}
