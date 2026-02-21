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
    const wallet: string = req.user?.walletAddress;
    return this.service.events$.pipe(
      filter((evt) => evt.walletAddress === wallet),
      map((evt) => ({
        data: JSON.stringify(evt.notification),
      })),
    );
  }
}
