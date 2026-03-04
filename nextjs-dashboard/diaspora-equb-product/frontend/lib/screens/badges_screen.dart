import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';

class BadgesScreen extends StatelessWidget {
  const BadgesScreen({super.key});

  static const _badges = [
    _BadgeData('First Equb Completed', 'Complete your first equb cycle', Icons.emoji_events_rounded, true),
    _BadgeData('Tier 2 Unlocked', 'Reach credit tier 2', Icons.trending_up_rounded, false),
    _BadgeData('Zero Defaults x10', 'Complete 10 rounds with zero defaults', Icons.verified_rounded, false),
    _BadgeData('Trusted Danna', 'Create and complete 5 equbs as Danna', Icons.star_rounded, false),
    _BadgeData('100% Consistency', 'Never miss a contribution deadline', Icons.check_circle_rounded, false),
    _BadgeData('Diaspora Pioneer', 'Be among the first 100 users', Icons.rocket_launch_rounded, true),
    _BadgeData('Community Builder', 'Refer 10 active users', Icons.people_rounded, false),
    _BadgeData('Whale Contributor', 'Contribute over \$10,000 total', Icons.account_balance_rounded, false),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: AppTheme.bgGradient(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Achievement Badges'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your collection of soulbound NFT badges',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  _categoryChip(context, 'All', true),
                  const SizedBox(width: 8),
                  _categoryChip(context, 'Equb', false),
                  const SizedBox(width: 8),
                  _categoryChip(context, 'Credit', false),
                  const SizedBox(width: 8),
                  _categoryChip(context, 'Danna', false),
                  const SizedBox(width: 8),
                  _categoryChip(context, 'Community', false),
                ],
              ),
              const SizedBox(height: 20),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.85,
                ),
                itemCount: _badges.length,
                itemBuilder: (context, i) => _buildBadgeCard(context, _badges[i]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryChip(BuildContext context, String label, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.buttonColor(context) : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: isSelected ? null : Border.all(color: AppTheme.textHintColor(context)),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
          color: isSelected ? AppTheme.buttonTextColor(context) : AppTheme.textSecondaryColor(context))),
    );
  }

  Widget _buildBadgeCard(BuildContext context, _BadgeData badge) {
    return GestureDetector(
      onTap: () => _showBadgeDetail(context, badge),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
          boxShadow: AppTheme.subtleShadowFor(context),
          border: badge.earned ? Border.all(color: AppTheme.accentYellowDark, width: 2) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: badge.earned
                    ? AppTheme.accentYellow.withValues(alpha: 0.2)
                    : AppTheme.textHintColor(context).withValues(alpha: 0.2),
              ),
              child: Icon(badge.icon, size: 28,
                  color: badge.earned ? AppTheme.accentYellowDark : AppTheme.textTertiaryColor(context)),
            ),
            const SizedBox(height: 12),
            Text(badge.name, textAlign: TextAlign.center, maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: badge.earned ? AppTheme.textPrimaryColor(context) : AppTheme.textTertiaryColor(context))),
            const SizedBox(height: 4),
            if (!badge.earned)
              Icon(Icons.lock_rounded, size: 14, color: AppTheme.textHintColor(context)),
          ],
        ),
      ),
    );
  }

  void _showBadgeDetail(BuildContext context, _BadgeData badge) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: badge.earned
                    ? AppTheme.accentYellow.withValues(alpha: 0.2)
                    : AppTheme.textHintColor(ctx).withValues(alpha: 0.2),
              ),
              child: Icon(badge.icon, size: 36,
                  color: badge.earned ? AppTheme.accentYellowDark : AppTheme.textTertiaryColor(ctx)),
            ),
            const SizedBox(height: 16),
            Text(badge.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(badge.requirement, textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: badge.earned ? AppTheme.positive.withValues(alpha: 0.15) : AppTheme.textHintColor(ctx).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(badge.earned ? 'Earned' : 'Locked',
                  style: TextStyle(fontWeight: FontWeight.w600,
                      color: badge.earned ? AppTheme.positive : AppTheme.textTertiaryColor(ctx))),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _BadgeData {
  final String name;
  final String requirement;
  final IconData icon;
  final bool earned;

  const _BadgeData(this.name, this.requirement, this.icon, this.earned);
}
