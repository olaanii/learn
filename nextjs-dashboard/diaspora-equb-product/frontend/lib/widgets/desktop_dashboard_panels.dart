import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../providers/network_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/wallet_provider.dart';
import '../services/wallet_service.dart';
import 'desktop_layout.dart';

class DesktopQuickTransferCard extends StatefulWidget {
  const DesktopQuickTransferCard({super.key});

  @override
  State<DesktopQuickTransferCard> createState() =>
      _DesktopQuickTransferCardState();
}

class _DesktopQuickTransferCardState extends State<DesktopQuickTransferCard> {
  final _recipientController = TextEditingController();
  final _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _amountController.text = '0.00';
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  double _currentAmount() {
    return double.tryParse(_amountController.text.trim()) ?? 0.0;
  }

  void _fillMaxAmount(String balance) {
    final parsed = double.tryParse(balance) ?? 0.0;
    _amountController.text = parsed.toStringAsFixed(2);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final balance = double.tryParse(wallet.balance) ?? 0.0;
    final amount = _currentAmount();
    final remaining = balance - amount;
    final exchangeRate = wallet.rates['EUR']?.toStringAsFixed(2) ?? '0.95';

    return DesktopCardSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Transfer',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Use normal keyboard input for recipient and amount.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => context.push('/pay'),
                child: const Text('Open Pay'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _DesktopFieldShell(
            label: 'Recipient',
            trailing: TextButton(
              onPressed: _recipientController.clear,
              child: const Text('Clear'),
            ),
            child: TextField(
              controller: _recipientController,
              decoration: const InputDecoration(
                hintText: 'Recipient address or saved contact',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _DesktopFieldShell(
            label: 'Amount',
            trailing: TextButton(
              onPressed: () => _fillMaxAmount(wallet.balance),
              child: const Text('Max'),
            ),
            child: TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: '0.00',
                prefixText: '\$ ',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                suffixText: wallet.token,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.cardColor(context).withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
              border: AppTheme.borderFor(context, opacity: 0.04),
            ),
            child: Column(
              children: [
                _TransferInfoRow(
                  label: 'Available balance',
                  value: '\$${balance.toStringAsFixed(2)}',
                ),
                const SizedBox(height: 8),
                _TransferInfoRow(
                  label: 'Balance after transfer',
                  value: '\$${remaining.toStringAsFixed(2)}',
                ),
                const SizedBox(height: 8),
                _TransferInfoRow(
                  label: 'Exchange rate',
                  value: '1 USD = $exchangeRate EUR',
                ),
                const SizedBox(height: 8),
                const _TransferInfoRow(
                  label: 'Transaction fee',
                  value: '\$0.00',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => context.push('/pay'),
                  child: const Text('Send'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.push('/fund-wallet'),
                  child: const Text('Fund Wallet'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DesktopSupportRail extends StatelessWidget {
  const DesktopSupportRail({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DesktopWorkspaceStatusCard(),
          const SizedBox(height: AppTheme.desktopSectionGap),
          const DesktopShortcutsCard(),
          const SizedBox(height: AppTheme.desktopSectionGap),
          const DesktopRecentActivityCard(),
        ],
      ),
    );
  }
}

class DesktopWorkspaceStatusCard extends StatelessWidget {
  const DesktopWorkspaceStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final notifications = context.watch<NotificationProvider>().unreadCount;
    final network = context.watch<NetworkProvider>();
    final walletService = context.watch<WalletService>();
    final balance = double.tryParse(wallet.balance) ?? 0.0;
    final isConnected = walletService.isConnected;
    final statusColor = isConnected ? AppTheme.positive : AppTheme.warningColor;

    return DesktopCardSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Workspace Status',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.buttonColor(context).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  network.shortNetworkName.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.buttonColor(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusColor.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Icon(
                  isConnected
                      ? Icons.check_circle_rounded
                      : Icons.account_balance_wallet_rounded,
                  size: 18,
                  color: statusColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isConnected
                        ? 'Wallet connected'
                        : 'Connect wallet from profile',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.textPrimaryColor(context),
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '\$${_formatBalance(balance)}',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Selected token: ${wallet.token}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SupportMetric(
                  label: 'Alerts',
                  value: '$notifications',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SupportMetric(
                  label: 'Rates',
                  value: wallet.rates.isEmpty ? '--' : 'Live',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DesktopShortcutsCard extends StatelessWidget {
  const DesktopShortcutsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final notifications = context.watch<NotificationProvider>().unreadCount;

    return DesktopCardSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Shortcuts',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 14),
          _SupportActionTile(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: notifications > 0
                ? '$notifications unread updates'
                : 'All caught up',
            onTap: () => context.push('/notifications'),
          ),
          const SizedBox(height: 10),
          _SupportActionTile(
            icon: Icons.person_outline_rounded,
            title: 'Profile',
            subtitle: 'Manage wallet and account details',
            onTap: () => context.push('/profile'),
          ),
          const SizedBox(height: 10),
          _SupportActionTile(
            icon: Icons.sync_rounded,
            title: 'Transactions',
            subtitle: 'Open the full transaction history',
            onTap: () => context.push('/transactions'),
          ),
        ],
      ),
    );
  }
}

class DesktopRecentActivityCard extends StatelessWidget {
  const DesktopRecentActivityCard({super.key});

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final txList = wallet.transactions.take(3).toList();

    return DesktopCardSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Activity',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 14),
          if (txList.isEmpty)
            Text(
              wallet.isLoading
                  ? 'Loading recent activity...'
                  : 'No recent transactions yet',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            Column(
              children: txList
                  .map((tx) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _RecentTxTile(tx: tx),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _DesktopFieldShell extends StatelessWidget {
  final String label;
  final Widget child;
  final Widget? trailing;

  const _DesktopFieldShell({
    required this.label,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: AppTheme.borderFor(context, opacity: 0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontSize: 12,
                        color: AppTheme.textTertiaryColor(context),
                      ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          child,
        ],
      ),
    );
  }
}

class _TransferInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _TransferInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textTertiaryColor(context),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryColor(context),
          ),
        ),
      ],
    );
  }
}

class _SupportMetric extends StatelessWidget {
  final String label;
  final String value;

  const _SupportMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _SupportActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SupportActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardColor(context).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: AppTheme.borderFor(context, opacity: 0.04),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color:
                    AppTheme.textPrimaryColor(context).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 20,
                color: AppTheme.textPrimaryColor(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_rounded,
              size: 18,
              color: AppTheme.textTertiaryColor(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentTxTile extends StatelessWidget {
  final Map<String, dynamic> tx;

  const _RecentTxTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final type = tx['type'] as String? ?? 'received';
    final isSent = type == 'sent';
    final amount = double.tryParse(tx['amount']?.toString() ?? '0') ?? 0.0;
    final token = tx['token']?.toString() ?? 'USDC';
    final counterparty =
        isSent ? tx['to']?.toString() ?? '' : tx['from']?.toString() ?? '';
    final display = counterparty.length > 10
        ? '${counterparty.substring(0, 6)}...${counterparty.substring(counterparty.length - 4)}'
        : counterparty;
    final color = isSent ? AppTheme.negative : AppTheme.positive;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isSent ? Icons.north_east_rounded : Icons.south_west_rounded,
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  display.isEmpty ? 'Unknown wallet' : display,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  token,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            '${isSent ? '-' : '+'}\$${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatBalance(double balance) {
  final parts = balance.toStringAsFixed(2).split('.');
  final whole = parts.first;
  final decimals = parts.last;
  final buffer = StringBuffer();
  for (int index = 0; index < whole.length; index++) {
    if (index > 0 && (whole.length - index) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(whole[index]);
  }
  return '$buffer.$decimals';
}
