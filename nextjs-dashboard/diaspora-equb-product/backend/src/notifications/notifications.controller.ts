import {
  Controller,
  Get,
  Param,
  Patch,
  Query,
  Req,
  Sse,
  MessageEvent,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { Observable, filter, map } from 'rxjs';
import { NotificationsService } from './notifications.service';

@ApiTags('Notifications')
@ApiBearerAuth()
@Controller('notifications')
export class NotificationsController {
  constructor(private readonly service: NotificationsService) {}

  @Get()
  @ApiOperation({ summary: 'List notifications for the authenticated user' })
  async list(
    @Req() req: any,
    @Query('limit') limit = 50,
    @Query('offset') offset = 0,
  ) {
    const wallet: string = req.user?.walletAddress;
    if (!wallet) return [];
    return this.service.findForWallet(wallet, +limit, +offset);
  }

  @Get('incremental')
  @ApiOperation({
    summary:
      'Get notifications created after a cursor (replay-safe incremental sync)',
  })
  async incremental(
    @Req() req: any,
    @Query('afterCreatedAt') afterCreatedAt?: string,
    @Query('afterId') afterId?: string,
    @Query('limit') limit = 50,
  ) {
    const wallet: string = req.user?.walletAddress;
    if (!wallet) {
      return { items: [], nextCursor: null, hasMore: false };
    }

    let parsedAfter: Date | undefined;
    if (afterCreatedAt) {
      const date = new Date(afterCreatedAt);
      if (!Number.isNaN(date.getTime())) {
        parsedAfter = date;
      }
    }

    return this.service.findForWalletIncremental(
      wallet,
      parsedAfter,
      afterId,
      +limit,
    );
  }

  @Get('unread-count')
  @ApiOperation({ summary: 'Get unread notification count' })
  async unreadCount(@Req() req: any) {
    const wallet: string = req.user?.walletAddress;
    if (!wallet) return { count: 0 };
    const count = await this.service.unreadCount(wallet);
    return { count };
  }

  @Patch(':id/read')
  @ApiOperation({ summary: 'Mark a notification as read' })
  async markRead(@Req() req: any, @Param('id') id: string) {
    const wallet: string = req.user?.walletAddress;
    if (!wallet) return;
    await this.service.markRead(id, wallet);
    return { ok: true };
  }

  @Patch('read-all')
  @ApiOperation({ summary: 'Mark all notifications as read' })
  async markAllRead(@Req() req: any) {
    const wallet: string = req.user?.walletAddress;
    if (!wallet) return;
    await this.service.markAllRead(wallet);
    return { ok: true };
  }

  @Sse('stream')
  @ApiOperation({
    summary: 'SSE stream of real-time notifications for the authenticated user',
  })
  stream(@Req() req: any): Observable<MessageEvent> {
    const wallet: string = String(req.user?.walletAddress || '')
      .trim()
      .toLowerCase();
    return this.service.events$.pipe(
      filter((evt) => evt.walletAddress.toLowerCase() === wallet),
      map((evt) => ({
        data: evt.notification,
      })),
    );
  }
}
