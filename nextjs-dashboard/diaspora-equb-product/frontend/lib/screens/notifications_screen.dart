import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';
import '../config/theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().loadNotifications();
    });
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'round_closed':
        return Icons.event_available;
      case 'payout_received':
        return Icons.payments_outlined;
      case 'contribution_confirmed':
        return Icons.check_circle_outline;
      case 'default_triggered':
        return Icons.warning_amber_rounded;
      case 'collateral_slashed':
        return Icons.remove_circle_outline;
      case 'pool_joined':
        return Icons.group_add_outlined;
      case 'stream_frozen':
        return Icons.ac_unit;
      case 'credit_updated':
        return Icons.trending_up;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'payout_received':
      case 'contribution_confirmed':
      case 'pool_joined':
        return AppTheme.successColor;
      case 'default_triggered':
      case 'collateral_slashed':
      case 'stream_frozen':
        return AppTheme.dangerColor;
      case 'round_closed':
        return AppTheme.primaryColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Notifications'),
          actions: [
            TextButton(
              onPressed: () =>
                  context.read<NotificationProvider>().markAllRead(),
              child: const Text('Mark all read'),
            ),
          ],
        ),
        body: Consumer<NotificationProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading && provider.notifications.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (provider.notifications.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_none,
                        size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No notifications yet',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () => provider.loadNotifications(),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: provider.notifications.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 72),
                itemBuilder: (context, index) {
                  final n = provider.notifications[index];
                  final color = _colorForType(n.type);

                  return ListTile(
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_iconForType(n.type), color: color, size: 22),
                    ),
                    title: Text(
                      n.title,
                      style: TextStyle(
                        fontWeight: n.read ? FontWeight.w400 : FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      n.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _timeAgo(n.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                        if (!n.read) ...[
                          const SizedBox(height: 4),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppTheme.primaryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    onTap: () {
                      if (!n.read) provider.markRead(n.id);
                    },
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
