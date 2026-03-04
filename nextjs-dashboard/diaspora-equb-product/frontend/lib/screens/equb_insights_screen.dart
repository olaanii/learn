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

  bool _hasActiveFilters(EqubInsightsProvider insights) {
    return insights.timeRange != '7d' ||
        insights.token != 'all' ||
        insights.status != 'all' ||
        insights.metric != 'joins';
  }

  void _showFilterSheet(BuildContext context, EqubInsightsProvider insights, String wallet) {
    String tempTime = insights.timeRange;
    String tempToken = insights.token;
    String tempStatus = insights.status;
    String tempMetric = insights.metric;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            Widget buildDropdown(String label, String value, List<String> items, ValueChanged<String> onChanged) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondaryColor(context))),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.bgGradient(context).colors.first.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.textHintColor(context).withValues(alpha: 0.3)),
                    ),
                    child: DropdownButton<String>(
                      value: value,
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                      dropdownColor: AppTheme.cardColor(context),
                      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setSheetState(() => onChanged(v));
                        }
                      },
                    ),
                  ),
                ],
              );
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.textHintColor(context), borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 16),
                  Text('Filters', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: buildDropdown('Time Range', tempTime, const ['24h', '7d', '30d', '90d'], (v) => tempTime = v)),
                    const SizedBox(width: 12),
                    Expanded(child: buildDropdown('Token', tempToken, const ['all', 'native'], (v) => tempToken = v)),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: buildDropdown('Status', tempStatus, const ['all', 'active', 'completed'], (v) => tempStatus = v)),
                    const SizedBox(width: 12),
                    Expanded(child: buildDropdown('Metric', tempMetric, const ['joins', 'contributions'], (v) => tempMetric = v)),
                  ]),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        insights.setTimeRange(tempTime);
                        insights.setToken(tempToken);
                        insights.setStatus(tempStatus);
                        insights.setMetric(tempMetric);
                        insights.applyFiltersAndReload(wallet);
                        Navigator.pop(ctx);
                      },
                      child: const Text('Apply Filters'),
                    ),
                  ),
                  if (_hasActiveFilters(insights)) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        insights.setTimeRange('7d');
                        insights.setToken('all');
                        insights.setStatus('all');
                        insights.setMetric('joins');
                        insights.applyFiltersAndReload(wallet);
                        Navigator.pop(ctx);
                      },
                      child: Text('Clear filters', style: TextStyle(color: AppTheme.textTertiaryColor(context))),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<AuthProvider>().walletAddress;

    return Container(
      decoration: BoxDecoration(gradient: AppTheme.bgGradient(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Equb Insights'),
        ),
        body: wallet == null
            ? const Center(child: Text('Wallet is not connected.'))
            : Consumer<EqubInsightsProvider>(
                builder: (context, insights, _) {
                  final hasFilters = _hasActiveFilters(insights);
                  return RefreshIndicator(
                    onRefresh: () => insights.refresh(wallet),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      children: [
                        // Filter bar
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Insights',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            Stack(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.tune_rounded, size: 22),
                                  onPressed: () => _showFilterSheet(context, insights, wallet),
                                  tooltip: 'Filters',
                                ),
                                if (hasFilters)
                                  Positioned(
                                    right: 8, top: 8,
                                    child: Container(
                                      width: 8, height: 8,
                                      decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.accentYellow),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _panelCard(
                          context: context,
                          title: 'Popular trends',
                          child: _buildPopularPanel(context, insights, wallet),
                        ),
                        const SizedBox(height: 12),
                        _panelCard(
                          context: context,
                          title: 'My joined progress',
                          child: _buildJoinedPanel(context, insights, wallet),
                        ),
                        const SizedBox(height: 12),
                        _panelCard(
                          context: context,
                          title: 'Summary',
                          child: _buildSummaryPanel(context, insights, wallet),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildPopularPanel(BuildContext context, EqubInsightsProvider insights, String wallet) {
    if (insights.popularLoading) {
      return _panelSkeleton(context: context, height: 180);
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
        Text(first['poolName']?.toString() ?? 'Top Equb'),
        const SizedBox(height: 8),
        SizedBox(height: 160, child: _lineChart(points)),
      ],
    );
  }

  Widget _buildJoinedPanel(BuildContext context, EqubInsightsProvider insights, String wallet) {
    if (insights.joinedLoading) {
      return _panelSkeleton(context: context, height: 180);
    }

    if (insights.joinedError != null) {
      return _panelError(
        message: insights.joinedError!,
        onRetry: () => insights.retryJoined(wallet),
      );
    }

    if (insights.joinedEmpty) {
      return const Text('You have not joined any equbs for current filters.');
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
              color: AppTheme.cardColor(context),
              borderRadius: BorderRadius.circular(12),
              boxShadow: AppTheme.subtleShadowFor(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pool['poolName']?.toString() ?? 'Equb'),
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

  Widget _buildSummaryPanel(BuildContext context, EqubInsightsProvider insights, String wallet) {
    if (insights.summaryLoading) {
      return _panelSkeleton(context: context, height: 90);
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
        Expanded(child: _summaryBox(context, 'Active', summary['activePools'] ?? 0)),
        const SizedBox(width: 8),
        Expanded(child: _summaryBox(context, 'Ending Soon', summary['endingSoon'] ?? 0)),
        const SizedBox(width: 8),
        Expanded(
          child: _summaryBox(context, 'Winner Pending', summary['winnerPending'] ?? 0),
        ),
      ],
    );
  }

  Widget _summaryBox(BuildContext context, String title, Object value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.subtleShadowFor(context),
      ),
      child: Column(
        children: [
          Text(value.toString(),
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor(context)),
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
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
        boxShadow: AppTheme.subtleShadowFor(context),
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

  Widget _panelSkeleton({required BuildContext context, required double height}) {
    return Shimmer.fromColors(
      baseColor: AppTheme.textHintColor(context).withValues(alpha: 0.25),
      highlightColor: AppTheme.cardColor(context),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AppTheme.textHintColor(context).withValues(alpha: 0.2),
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
