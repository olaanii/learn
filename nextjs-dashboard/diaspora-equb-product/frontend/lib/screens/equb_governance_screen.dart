import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/proposal.dart';
import '../providers/governance_provider.dart';
import '../providers/auth_provider.dart';
import '../services/wallet_service.dart';
import '../services/app_snackbar_service.dart';
import '../widgets/desktop_layout.dart';

class EqubGovernanceScreen extends StatefulWidget {
  final String equbId;
  final bool embeddedDesktop;

  const EqubGovernanceScreen({
    super.key,
    required this.equbId,
    this.embeddedDesktop = false,
  });

  @override
  State<EqubGovernanceScreen> createState() => _EqubGovernanceScreenState();
}

class _EqubGovernanceScreenState extends State<EqubGovernanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GovernanceProvider>().fetchProposals(widget.equbId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gov = context.watch<GovernanceProvider>();
    final embeddedDesktop = widget.embeddedDesktop && AppTheme.isDesktop(context);

    final tabView = gov.isLoading && gov.activeProposals.isEmpty && gov.pastProposals.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(
            controller: _tabController,
            children: [
              _buildProposalList(
                context,
                gov.activeProposals,
                isActive: true,
                emptyIcon: Icons.how_to_vote_rounded,
                emptyTitle: 'No Active Proposals',
                emptySubtitle:
                    'When the Danna proposes a rule change, it will appear here for voting.',
              ),
              _buildProposalList(
                context,
                gov.pastProposals,
                isActive: false,
                emptyIcon: Icons.history_rounded,
                emptyTitle: 'No Past Proposals',
                emptySubtitle:
                    'Completed governance votes will be listed here.',
              ),
            ],
          );

    if (embeddedDesktop) {
      return DesktopContent(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: DesktopSectionTitle(
                    title: 'Governance',
                    subtitle: 'Review active proposals, past votes, and propose rule changes from the desktop workspace.',
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () => gov.fetchProposals(widget.equbId),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => _showProposeDialog(context),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Propose'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.accentYellowDark,
              labelColor: AppTheme.textPrimaryColor(context),
              unselectedLabelColor: AppTheme.textTertiaryColor(context),
              tabs: const [
                Tab(text: 'Active Proposals'),
                Tab(text: 'Past Results'),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(child: tabView),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(gradient: AppTheme.bgGradient(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Governance'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () =>
                  gov.fetchProposals(widget.equbId),
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: AppTheme.accentYellowDark,
            labelColor: AppTheme.textPrimaryColor(context),
            unselectedLabelColor: AppTheme.textTertiaryColor(context),
            tabs: const [
              Tab(text: 'Active Proposals'),
              Tab(text: 'Past Results'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showProposeDialog(context),
          backgroundColor: AppTheme.buttonColor(context),
          foregroundColor: AppTheme.buttonTextColor(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Propose'),
        ),
        body: tabView,
      ),
    );
  }

  Widget _buildProposalList(
    BuildContext context,
    List<Proposal> proposals, {
    required bool isActive,
    required IconData emptyIcon,
    required String emptyTitle,
    required String emptySubtitle,
  }) {
    if (proposals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(emptyIcon,
                  size: 48,
                  color: AppTheme.textTertiaryColor(context)),
              const SizedBox(height: 16),
              Text(emptyTitle,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(emptySubtitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          context.read<GovernanceProvider>().fetchProposals(widget.equbId),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: proposals.length,
        itemBuilder: (context, index) =>
            _buildProposalCard(context, proposals[index], isActive),
      ),
    );
  }

  Widget _buildProposalCard(
      BuildContext context, Proposal proposal, bool isActive) {
    final totalVotes = proposal.totalVotes;
    final yesPercent = proposal.yesPercent;

    Color statusColor;
    String statusLabel;
    if (proposal.isActive) {
      statusColor = AppTheme.accentYellowDark;
      statusLabel = 'Active';
    } else if (proposal.isPassed) {
      statusColor = AppTheme.positive;
      statusLabel = 'Passed';
    } else if (proposal.isCancelled) {
      statusColor = AppTheme.warningColor;
      statusLabel = 'Cancelled';
    } else {
      statusColor = AppTheme.negative;
      statusLabel = 'Rejected';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                if (proposal.onChainProposalId != null)
                  Text(
                    '#${proposal.onChainProposalId}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textTertiaryColor(context),
                      fontFamily: 'monospace',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              proposal.description.isNotEmpty
                  ? proposal.description
                  : 'Rule change proposal',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (proposal.proposer != null) ...[
              const SizedBox(height: 6),
              Text(
                'By ${_truncateAddress(proposal.proposer!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textTertiaryColor(context),
                  fontFamily: 'monospace',
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Vote progress bar
            Row(
              children: [
                Text('Yes ${proposal.yesVotes}',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.positive,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('No ${proposal.noVotes}',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.negative,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: totalVotes > 0 ? yesPercent : 0,
                minHeight: 8,
                backgroundColor: totalVotes > 0
                    ? AppTheme.negative.withValues(alpha: 0.3)
                    : AppTheme.textTertiaryColor(context).withValues(alpha: 0.2),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppTheme.positive),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '$totalVotes total vote${totalVotes == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textTertiaryColor(context),
                  ),
                ),
                const Spacer(),
                Text(
                  proposal.timeRemaining,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textTertiaryColor(context),
                  ),
                ),
              ],
            ),

            if (isActive && proposal.isActive) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _castVote(context, proposal, true),
                      icon: const Icon(Icons.thumb_up_outlined, size: 18),
                      label: const Text('Vote Yes'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.positive,
                        side: const BorderSide(color: AppTheme.positive),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _castVote(context, proposal, false),
                      icon: const Icon(Icons.thumb_down_outlined, size: 18),
                      label: const Text('Vote No'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.negative,
                        side: const BorderSide(color: AppTheme.negative),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (proposal.isExpired && proposal.yesVotes > proposal.noVotes)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _executeProposal(context, proposal),
                      icon: const Icon(Icons.gavel_rounded, size: 18),
                      label: const Text('Execute Proposal'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.buttonColor(context),
                        foregroundColor: AppTheme.buttonTextColor(context),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _castVote(
      BuildContext context, Proposal proposal, bool support) async {
    final wallet = context.read<WalletService>();
    final auth = context.read<AuthProvider>();
    final gov = context.read<GovernanceProvider>();

    if (!wallet.isConnected) {
      AppSnackbarService.instance.warning(
        message: 'Connect your wallet first to vote.',
        dedupeKey: 'gov_wallet_required',
      );
      return;
    }

    if (proposal.onChainProposalId == null) {
      AppSnackbarService.instance.error(
        message: 'Proposal has no on-chain ID.',
        dedupeKey: 'gov_no_onchain_id',
      );
      return;
    }

    AppSnackbarService.instance.info(
      message: 'Building vote TX — confirm in wallet...',
      dedupeKey: 'gov_vote_pending',
      duration: const Duration(seconds: 3),
    );

    final txHash = await gov.vote(
      poolId: widget.equbId,
      onChainProposalId: proposal.onChainProposalId!,
      support: support,
      callerAddress: wallet.walletAddress ?? auth.walletAddress ?? '',
    );

    if (!mounted) return;

    if (txHash != null) {
      AppSnackbarService.instance.success(
        message: 'Vote submitted! TX: ${txHash.substring(0, 16)}...',
        dedupeKey: 'gov_vote_success_$txHash',
      );
      unawaited(gov.fetchProposals(widget.equbId));
    } else {
      AppSnackbarService.instance.error(
        message: gov.errorMessage ?? 'Vote failed or was rejected.',
        dedupeKey: 'gov_vote_failed',
        duration: const Duration(seconds: 5),
      );
    }
  }

  Future<void> _executeProposal(
      BuildContext context, Proposal proposal) async {
    final wallet = context.read<WalletService>();
    final auth = context.read<AuthProvider>();
    final gov = context.read<GovernanceProvider>();

    if (!wallet.isConnected || proposal.onChainProposalId == null) return;

    AppSnackbarService.instance.info(
      message: 'Building execute TX — confirm in wallet...',
      dedupeKey: 'gov_execute_pending',
      duration: const Duration(seconds: 3),
    );

    final txHash = await gov.executeProposal(
      poolId: widget.equbId,
      onChainProposalId: proposal.onChainProposalId!,
      callerAddress: wallet.walletAddress ?? auth.walletAddress ?? '',
    );

    if (!mounted) return;

    if (txHash != null) {
      AppSnackbarService.instance.success(
        message: 'Proposal executed! TX: ${txHash.substring(0, 16)}...',
        dedupeKey: 'gov_execute_success_$txHash',
      );
      unawaited(gov.fetchProposals(widget.equbId));
    } else {
      AppSnackbarService.instance.error(
        message: gov.errorMessage ?? 'Execution failed.',
        dedupeKey: 'gov_execute_failed',
        duration: const Duration(seconds: 5),
      );
    }
  }

  void _showProposeDialog(BuildContext context) {
    final wallet = context.read<WalletService>();
    final auth = context.read<AuthProvider>();

    if (!wallet.isConnected) {
      AppSnackbarService.instance.warning(
        message: 'Connect your wallet to propose rule changes.',
        dedupeKey: 'gov_propose_wallet_required',
      );
      return;
    }

    final descController = TextEditingController();
    final gracePeriodController = TextEditingController(text: '86400');
    final roundDurationController = TextEditingController(text: '604800');
    final lateFeeController = TextEditingController(text: '5');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.textTertiaryColor(ctx).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Propose Rule Change',
                    style: Theme.of(ctx)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  'Only the pool creator (Danna) can propose changes. Members will vote.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textTertiaryColor(ctx),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Explain the proposed change...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: gracePeriodController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Grace Period (sec)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: roundDurationController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Round Duration (sec)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lateFeeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Late Fee (%)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final gov = context.read<GovernanceProvider>();

                      AppSnackbarService.instance.info(
                        message: 'Building proposal TX — confirm in wallet...',
                        dedupeKey: 'gov_propose_pending',
                        duration: const Duration(seconds: 3),
                      );

                      final txHash = await gov.proposeRuleChange(
                        poolId: widget.equbId,
                        rules: {
                          'equbType': 0,
                          'frequency': 0,
                          'payoutMethod': 0,
                          'gracePeriodSeconds':
                              int.tryParse(gracePeriodController.text) ?? 86400,
                          'penaltySeverity': 1,
                          'roundDurationSeconds':
                              int.tryParse(roundDurationController.text) ??
                                  604800,
                          'lateFeePercent':
                              int.tryParse(lateFeeController.text) ?? 5,
                        },
                        description: descController.text.trim(),
                        callerAddress: wallet.walletAddress ??
                            auth.walletAddress ??
                            '',
                      );

                      if (!mounted) return;

                      if (txHash != null) {
                        AppSnackbarService.instance.success(
                          message:
                              'Proposal submitted! TX: ${txHash.substring(0, 16)}...',
                          dedupeKey: 'gov_propose_success_$txHash',
                        );
                        unawaited(gov.fetchProposals(widget.equbId));
                      } else {
                        AppSnackbarService.instance.error(
                          message:
                              gov.errorMessage ?? 'Proposal failed.',
                          dedupeKey: 'gov_propose_failed',
                          duration: const Duration(seconds: 5),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.buttonColor(context),
                      foregroundColor: AppTheme.buttonTextColor(context),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    child: const Text('Submit Proposal',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _truncateAddress(String address) {
    if (address.length <= 12) return address;
    return '${address.substring(0, 8)}...${address.substring(address.length - 4)}';
  }
}
