import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/equb_insights_provider.dart';

class EqubInsightsScreen extends StatefulWidget {
  const EqubInsightsScreen({super.key});

  @override
  State<EqubInsightsScreen> createState() => _EqubInsightsScreenState();
}

class _EqubInsightsScreenState extends State<EqubInsightsScreen> {
  String? _loadedWallet;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wallet = context.read<AuthProvider>().walletAddress;
    if (wallet != null && wallet != _loadedWallet) {
      _loadedWallet = wallet;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<EqubInsightsProvider>().initializeForWallet(wallet);
      });
    } else if (wallet == null && _loadedWallet != null) {
      _loadedWallet = null;
      context.read<EqubInsightsProvider>().clearWalletContext();
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<AuthProvider>().walletAddress;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Equb Insights'),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: wallet == null
            ? const Center(child: Text('Wallet is not connected.'))
            : Consumer<EqubInsightsProvider>(
                builder: (context, insights, _) {
                  return RefreshIndicator(
                    onRefresh: () => insights.refresh(wallet),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      children: [
                        _buildFilters(context, insights, wallet),
                        const SizedBox(height: 12),
                        _panelCard(
                          context: context,
                          title: 'Popular trends',
                          child: _buildPopularPanel(insights, wallet),
                        ),
                        const SizedBox(height: 12),
                        _panelCard(
                          context: context,
                          title: 'My joined progress',
                          child: _buildJoinedPanel(insights, wallet),
                        ),
                        const SizedBox(height: 12),
                        _panelCard(
                          context: context,
                          title: 'Summary',
                          child: _buildSummaryPanel(insights, wallet),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildFilters(
    BuildContext context,
    EqubInsightsProvider insights,
    String wallet,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Filters', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _filterDropdown(
                  value: insights.timeRange,
                  items: const ['24h', '7d', '30d', '90d'],
                  onChanged: (v) => insights.setTimeRange(v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _filterDropdown(
                  value: insights.token,
                  items: const ['all', 'native'],
                  onChanged: (v) => insights.setToken(v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _filterDropdown(
                  value: insights.status,
                  items: const ['all', 'active', 'completed'],
                  onChanged: (v) => insights.setStatus(v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _filterDropdown(
                  value: insights.metric,
                  items: const ['joins', 'contributions'],
                  onChanged: (v) => insights.setMetric(v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => insights.applyFiltersAndReload(wallet),
              child: const Text('Apply filters'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
      items: items
          .map((item) => DropdownMenuItem<String>(
                value: item,
                child: Text(item),
              ))
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }

  Widget _buildPopularPanel(EqubInsightsProvider insights, String wallet) {
    if (insights.popularLoading) {
      return _panelSkeleton(height: 180);
    }

    if (insights.popularError != null) {
      return _panelError(
        message: insights.popularError!,
        onRetry: insights.retryPopular,
      );
    }

    if (insights.popularEmpty) {
      return const Text('No popular trend data for current filters.');
    }

    final first = insights.popularSeries.first;
    final points = ((first['points'] as List?) ?? [])
        .whereType<Map>()
        .map((row) => FlSpot(
              ((row['ts'] as num?) ?? 0).toDouble(),
              ((row['value'] as num?) ?? 0).toDouble(),
            ))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(first['poolName']?.toString() ?? 'Top pool'),
        const SizedBox(height: 8),
        SizedBox(height: 160, child: _lineChart(points)),
      ],
    );
  }

  Widget _buildJoinedPanel(EqubInsightsProvider insights, String wallet) {
    if (insights.joinedLoading) {
      return _panelSkeleton(height: 180);
    }

    if (insights.joinedError != null) {
      return _panelError(
        message: insights.joinedError!,
        onRetry: () => insights.retryJoined(wallet),
      );
    }

    if (insights.joinedEmpty) {
      return const Text('You have not joined any pools for current filters.');
    }

    return Column(
      children: insights.joinedPools.take(3).map((pool) {
        final points = ((pool['points'] as List?) ?? [])
            .whereType<Map>()
            .map((row) => FlSpot(
                  ((row['ts'] as num?) ?? 0).toDouble(),
                  ((row['value'] as num?) ?? 0).toDouble(),
                ))
            .toList();

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.backgroundLight.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pool['poolName']?.toString() ?? 'Pool'),
                const SizedBox(height: 4),
                Text(
                  'Completion: ${pool['completionPct'] ?? 0}% • Rounds: ${pool['roundsDone'] ?? 0}/${pool['roundsTotal'] ?? 0}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                SizedBox(height: 80, child: _lineChart(points, compact: true)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSummaryPanel(EqubInsightsProvider insights, String wallet) {
    if (insights.summaryLoading) {
      return _panelSkeleton(height: 90);
    }

    if (insights.summaryError != null) {
      return _panelError(
        message: insights.summaryError!,
        onRetry: () => insights.retrySummary(wallet),
      );
    }

    final summary = insights.summary;
    return Row(
      children: [
        Expanded(child: _summaryBox('Active', summary['activePools'] ?? 0)),
        const SizedBox(width: 8),
        Expanded(child: _summaryBox('Ending Soon', summary['endingSoon'] ?? 0)),
        const SizedBox(width: 8),
        Expanded(
          child: _summaryBox('Winner Pending', summary['winnerPending'] ?? 0),
        ),
      ],
    );
  }

  Widget _summaryBox(String title, Object value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value.toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _lineChart(List<FlSpot> points, {bool compact = false}) {
    if (points.isEmpty) {
      return const Center(child: Text('No points'));
    }

    final sorted = [...points]..sort((a, b) => a.x.compareTo(b.x));
    return LineChart(
      LineChartData(
        minX: sorted.first.x,
        maxX: sorted.last.x,
        minY: 0,
        lineBarsData: [
          LineChartBarData(
            spots: sorted,
            isCurved: true,
            barWidth: compact ? 2 : 3,
            color: AppTheme.primaryColor,
            belowBarData: BarAreaData(
              show: true,
              color: AppTheme.primaryColor.withValues(alpha: 0.18),
            ),
            dotData: const FlDotData(show: false),
          ),
        ],
        gridData: FlGridData(show: !compact),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
      ),
    );
  }

  Widget _panelCard({
    required BuildContext context,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _panelSkeleton({required double height}) {
    return Shimmer.fromColors(
      baseColor: AppTheme.textHint.withValues(alpha: 0.25),
      highlightColor: AppTheme.cardWhite,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AppTheme.textHint.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _panelError({
    required String message,
    required Future<void> Function() onRetry,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message, style: const TextStyle(color: AppTheme.dangerColor)),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: onRetry,
          child: const Text('Retry'),
        ),
      ],
    );
  }
}
