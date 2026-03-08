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
      case 'all_contributed':
        return Icons.groups_2_outlined;
      case 'default_triggered':
        return Icons.warning_amber_rounded;
      case 'collateral_slashed':
        return Icons.remove_circle_outline;
      case 'pool_joined':
        return Icons.group_add_outlined;
      case 'pool_created':
        return Icons.add_chart_outlined;
      case 'transfer_built':
        return Icons.north_east_rounded;
      case 'withdraw_built':
        return Icons.south_west_rounded;
      case 'wallet_bound':
        return Icons.verified_user_outlined;
      case 'collateral_deposit_confirmed':
        return Icons.shield_outlined;
      case 'collateral_released':
        return Icons.lock_open_outlined;
      case 'faucet_credited':
        return Icons.water_drop_outlined;
      case 'stream_frozen':
        return Icons.ac_unit;
      case 'credit_updated':
        return Icons.trending_up;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _colorForType(BuildContext context, String type) {
    switch (type) {
      case 'payout_received':
      case 'contribution_confirmed':
      case 'pool_joined':
      case 'pool_created':
      case 'wallet_bound':
      case 'collateral_deposit_confirmed':
      case 'collateral_released':
      case 'faucet_credited':
        return AppTheme.successColor;
      case 'transfer_built':
      case 'withdraw_built':
        return AppTheme.warningColor;
      case 'default_triggered':
      case 'collateral_slashed':
      case 'stream_frozen':
        return AppTheme.dangerColor;
      case 'round_closed':
      case 'all_contributed':
        return AppTheme.primaryColor;
      default:
        return AppTheme.textSecondaryColor(context);
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

  String _statusForNotification(AppNotification notification) {
    final status = notification.status;
    if (status != null) {
      return status;
    }

    switch (notification.type) {
      case 'transfer_built':
      case 'withdraw_built':
        return 'pending';
      default:
        return 'confirmed';
    }
  }

  Color _statusBgColor(String status) {
    switch (status) {
      case 'pending':
        return AppTheme.warningColor.withValues(alpha: 0.15);
      case 'failed':
        return AppTheme.dangerColor.withValues(alpha: 0.15);
      default:
        return AppTheme.successColor.withValues(alpha: 0.15);
    }
  }

  Color _statusTextColor(String status) {
    switch (status) {
      case 'pending':
        return AppTheme.warningColor;
      case 'failed':
        return AppTheme.dangerColor;
      default:
        return AppTheme.successColor;
    }
  }

  Color _kindBgColor(bool critical) {
    if (critical) {
      return AppTheme.dangerColor.withValues(alpha: 0.15);
    }
    return AppTheme.primaryColor.withValues(alpha: 0.15);
  }

  Color _kindTextColor(bool critical) {
    if (critical) {
      return AppTheme.dangerColor;
    }
    return AppTheme.primaryColor;
  }

  Future<void> _showNotificationDetails(
    BuildContext context,
    AppNotification notification, {
    required String status,
    required bool showStatusChip,
    required bool isCritical,
  }) {
    final chipBackground =
        showStatusChip ? _statusBgColor(status) : _kindBgColor(isCritical);
    final chipTextColor =
        showStatusChip ? _statusTextColor(status) : _kindTextColor(isCritical);
    final chipLabel =
        showStatusChip ? status.toUpperCase() : (isCritical ? 'ALERT' : 'INFO');

    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        title: Text(notification.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: chipBackground,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  chipLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: chipTextColor,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                notification.body,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textPrimaryColor(dialogContext),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _timeAgo(notification.createdAt),
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondaryColor(dialogContext),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _groupTitle(NotificationGroupItem group) {
    final poolSuffix = group.poolId != null ? ' in Equb #${group.poolId}' : '';

    switch (group.type) {
      case 'round_closed':
        return '${group.count} round updates$poolSuffix';
      case 'all_contributed':
        return '${group.count} rounds fully contributed$poolSuffix';
      case 'contribution_confirmed':
        return '${group.count} contributions confirmed$poolSuffix';
      case 'pool_joined':
        return '${group.count} equb join confirmations$poolSuffix';
      case 'pool_created':
        return '${group.count} equbs created';
      default:
        return '${group.count} grouped updates$poolSuffix';
    }
  }

  String _groupSubtitle(NotificationGroupItem group) {
    final latest = group.latestNotification;
    if (group.count <= 2) {
      return 'Tap to read all updates';
    }
    return 'Latest: ${latest.title}';
  }

  Future<void> _showGroupDetails(
    BuildContext context,
    NotificationGroupItem group,
  ) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        contentPadding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
        actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        title: Text(_groupTitle(group)),
        content: SizedBox(
          width: 520,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 380),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: group.notifications.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final n = group.notifications[index];
                final color = _colorForType(context, n.type);
                return ListTile(
                  dense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_iconForType(n.type), color: color, size: 18),
                  ),
                  title: Text(
                    n.title,
                    style: TextStyle(
                      fontWeight: n.read ? FontWeight.w500 : FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    n.body,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryColor(context),
                    ),
                  ),
                  trailing: Text(
                    _timeAgo(n.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textTertiaryColor(context),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppTheme.textTertiaryColor(context),
        ),
      ),
    );
  }

  Widget _buildSingleTile(
    BuildContext context,
    NotificationProvider provider,
    AppNotification n,
  ) {
    final color = _colorForType(context, n.type);
    final status = _statusForNotification(n);
    final showStatusChip = n.isTransaction;
    final isCritical = n.isCritical;

    return ListTile(
      isThreeLine: true,
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
          color: AppTheme.textSecondaryColor(context),
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: showStatusChip
                  ? _statusBgColor(status)
                  : _kindBgColor(isCritical),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              showStatusChip
                  ? status.toUpperCase()
                  : (isCritical ? 'ALERT' : 'INFO'),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: showStatusChip
                    ? _statusTextColor(status)
                    : _kindTextColor(isCritical),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _timeAgo(n.createdAt),
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textTertiaryColor(context),
                ),
              ),
              if (!n.read) ...[
                const SizedBox(width: 6),
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
        ],
      ),
      onTap: () async {
        if (!n.read) {
          await provider.markRead(n.id);
        }
        if (!context.mounted) return;
        await _showNotificationDetails(
          context,
          n,
          status: status,
          showStatusChip: showStatusChip,
          isCritical: isCritical,
        );
      },
    );
  }

  Widget _buildGroupTile(
    BuildContext context,
    NotificationProvider provider,
    NotificationGroupItem group,
  ) {
    final latest = group.latestNotification;
    final color = _colorForType(context, group.type);
    final unreadCount = group.notifications.where((n) => !n.read).length;

    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.layers_outlined, color: color, size: 22),
      ),
      title: Text(
        _groupTitle(group),
        style: TextStyle(
          fontWeight: group.hasUnread ? FontWeight.w600 : FontWeight.w500,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        _groupSubtitle(group),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          color: AppTheme.textSecondaryColor(context),
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'GROUP',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _timeAgo(latest.createdAt),
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textTertiaryColor(context),
            ),
          ),
          if (unreadCount > 0)
            Text(
              '$unreadCount unread',
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
      onTap: () async {
        if (group.hasUnread) {
          await provider.markReadMany(
            group.notifications.where((n) => !n.read).map((n) => n.id),
          );
        }
        if (!context.mounted) return;
        await _showGroupDetails(context, group);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: AppTheme.bgGradient(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Notifications'),
          actions: [
            Consumer<NotificationProvider>(
              builder: (context, provider, _) => TextButton(
                onPressed: provider.notifications.isEmpty
                    ? null
                    : () => provider.markAllRead(),
                child: const Text('Mark all read'),
              ),
            ),
          ],
        ),
        body: Consumer<NotificationProvider>(
          builder: (context, provider, _) {
            final sections = provider.displaySections;
            final unreadCount = provider.notifications
                .where((notification) => !notification.read)
                .length;
            final criticalCount = provider.notifications
                .where((notification) => notification.isCritical)
                .length;

            if (provider.isLoading && provider.notifications.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (sections.isEmpty) {
              return Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor(context),
                    borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                    boxShadow: AppTheme.subtleShadowFor(context),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.notifications_none_rounded,
                        size: 56,
                        color: AppTheme.textTertiaryColor(context),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'No notifications yet',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pool milestones, payout updates, wallet events, and critical alerts will collect here once activity begins.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () => provider.loadNotifications(),
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: _buildInboxSummary(
                      context,
                      unreadCount: unreadCount,
                      criticalCount: criticalCount,
                    ),
                  ),
                  if (sections.critical.isNotEmpty) ...[
                    _buildSectionHeader(context, 'Critical Alerts'),
                    for (final item in sections.critical) ...[
                      _buildSingleTile(context, provider, item.notification),
                      const Divider(height: 1, indent: 72),
                    ],
                  ],
                  if (sections.latest.isNotEmpty) ...[
                    _buildSectionHeader(context, 'Latest Updates'),
                    for (final item in sections.latest) ...[
                      _buildSingleTile(context, provider, item.notification),
                      const Divider(height: 1, indent: 72),
                    ],
                  ],
                  if (sections.grouped.isNotEmpty) ...[
                    _buildSectionHeader(context, 'Earlier Summaries'),
                    for (final item in sections.grouped) ...[
                      if (item is NotificationSingleItem)
                        _buildSingleTile(context, provider, item.notification)
                      else if (item is NotificationGroupItem)
                        _buildGroupTile(context, provider, item),
                      const Divider(height: 1, indent: 72),
                    ],
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInboxSummary(
    BuildContext context, {
    required int unreadCount,
    required int criticalCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: AppTheme.subtleShadowFor(context),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.notifications_active_outlined,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inbox overview',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  unreadCount == 0
                      ? 'You are caught up. New app and wallet events will appear here.'
                      : '$unreadCount unread updates${criticalCount > 0 ? ' including $criticalCount critical alerts' : ''}.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
