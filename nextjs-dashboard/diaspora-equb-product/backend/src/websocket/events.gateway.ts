import { Logger } from '@nestjs/common';
import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  OnGatewayConnection,
  OnGatewayDisconnect,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';

export interface EqubEvent {
  type:
    | 'contribution:received'
    | 'round:closed'
    | 'proposal:created'
    | 'vote:cast'
    | 'payout:sent'
    | 'equb:created'
    | 'member:joined'
    | 'default:triggered'
    | 'winner:randomizing'
    | 'winner:picked';
  poolId?: string;
  onChainPoolId?: number;
  data: Record<string, any>;
  timestamp: number;
}

@WebSocketGateway({ cors: { origin: '*' }, namespace: '/events' })
export class EventsGateway
  implements OnGatewayConnection, OnGatewayDisconnect
{
  private readonly logger = new Logger(EventsGateway.name);

  @WebSocketServer()
  server: Server;

  private eventBuffer: EqubEvent[] = [];
  private readonly MAX_BUFFER = 100;

  handleConnection(client: Socket) {
    this.logger.log(`Client connected: ${client.id}`);
  }

  handleDisconnect(client: Socket) {
    this.logger.log(`Client disconnected: ${client.id}`);
  }

  @SubscribeMessage('subscribe:pool')
  handleSubscribePool(client: Socket, poolId: string) {
    client.join(`pool:${poolId}`);
    return { event: 'subscribed', data: { poolId } };
  }

  @SubscribeMessage('subscribe:global')
  handleSubscribeGlobal(client: Socket) {
    client.join('global');
    return { event: 'subscribed', data: { channel: 'global' } };
  }

  @SubscribeMessage('unsubscribe:pool')
  handleUnsubscribePool(client: Socket, poolId: string) {
    client.leave(`pool:${poolId}`);
    return { event: 'unsubscribed', data: { poolId } };
  }

  emitToPool(poolId: string, event: EqubEvent) {
    this.logger.debug(`Event ${event.type} for pool ${poolId}`);
    this.bufferEvent(event);
    this.server?.to(`pool:${poolId}`).emit(event.type, event);
  }

  emitGlobal(event: EqubEvent) {
    this.logger.debug(`Global event ${event.type}`);
    this.bufferEvent(event);
    this.server?.to('global').emit(event.type, event);
  }

  emitWinnerRandomizing(
    poolId: string,
    data: {
      roundNumber: number;
      eligibleMembers: string[];
      totalPrize: number;
    },
  ) {
    const event: EqubEvent = {
      type: 'winner:randomizing',
      poolId,
      data,
      timestamp: Date.now(),
    };
    this.emitToPool(poolId, event);
  }

  emitWinnerPicked(
    poolId: string,
    data: {
      roundNumber: number;
      winnerWallet: string;
      payoutAmount: number;
    },
  ) {
    const event: EqubEvent = {
      type: 'winner:picked',
      poolId,
      data,
      timestamp: Date.now(),
    };
    this.emitToPool(poolId, event);
  }

  getRecentEvents(limit = 20): EqubEvent[] {
    return this.eventBuffer.slice(-limit);
  }

  getRecentEventsForPool(poolId: string, limit = 20): EqubEvent[] {
    return this.eventBuffer.filter((e) => e.poolId === poolId).slice(-limit);
  }

  private bufferEvent(event: EqubEvent) {
    this.eventBuffer.push(event);
    if (this.eventBuffer.length > this.MAX_BUFFER) {
      this.eventBuffer = this.eventBuffer.slice(-this.MAX_BUFFER);
    }
  }
}
