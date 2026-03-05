import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../config/theme.dart';

class LotteryDrawModal extends StatefulWidget {
  final List<String> eligibleMembers;
  final Future<String?> Function() onDraw;

  const LotteryDrawModal({
    super.key,
    required this.eligibleMembers,
    required this.onDraw,
  });

  /// Show the lottery modal and return the winner address (or null on failure).
  static Future<String?> show(
    BuildContext context, {
    required List<String> eligibleMembers,
    required Future<String?> Function() onDraw,
  }) {
    return showModalBottomSheet<String?>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LotteryDrawModal(
        eligibleMembers: eligibleMembers,
        onDraw: onDraw,
      ),
    );
  }

  @override
  State<LotteryDrawModal> createState() => _LotteryDrawModalState();
}

class _LotteryDrawModalState extends State<LotteryDrawModal>
    with SingleTickerProviderStateMixin {
  Timer? _spinTimer;
  int _currentIndex = 0;
  bool _isDrawing = true;
  String? _winner;
  String? _error;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _startSpin();
    _performDraw();
  }

  @override
  void dispose() {
    _spinTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _startSpin() {
    _spinTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (!mounted) return;
      setState(() {
        _currentIndex = (_currentIndex + 1) % widget.eligibleMembers.length;
      });
    });
  }

  Future<void> _performDraw() async {
    try {
      final winner = await widget.onDraw();
      if (!mounted) return;

      // Slow-down animation before reveal
      _spinTimer?.cancel();
      final rng = Random();
      int delay = 120;
      for (int i = 0; i < 12; i++) {
        await Future.delayed(Duration(milliseconds: delay));
        if (!mounted) return;
        setState(() {
          _currentIndex =
              (_currentIndex + 1) % widget.eligibleMembers.length;
        });
        delay += 40 + rng.nextInt(30);
      }

      setState(() {
        _isDrawing = false;
        _winner = winner;
      });

      // Auto-dismiss after 4 seconds
      await Future.delayed(const Duration(seconds: 4));
      if (mounted) Navigator.of(context).pop(winner);
    } catch (e) {
      if (!mounted) return;
      _spinTimer?.cancel();
      setState(() {
        _isDrawing = false;
        _error = e.toString();
      });
    }
  }

  String _truncate(String addr) {
    if (addr.length < 14) return addr;
    return '${addr.substring(0, 8)}...${addr.substring(addr.length - 6)}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkCard : Colors.white;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary;

    return Container(
      margin: const EdgeInsets.only(top: 80),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: (isDark ? AppTheme.darkBorder : Colors.grey[300]),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Icon(
                _winner != null
                    ? Icons.emoji_events_rounded
                    : Icons.casino_rounded,
                size: 48,
                color: _winner != null
                    ? AppTheme.accentYellow
                    : (isDark ? AppTheme.darkAccent : AppTheme.secondaryColor),
              ),
              const SizedBox(height: 16),
              Text(
                _winner != null
                    ? 'Winner Selected!'
                    : (_error != null ? 'Draw Failed' : 'Drawing Winner...'),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 24),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.negative,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Close'),
                ),
              ] else ...[
                // Lottery slot display
                _buildSlotDisplay(isDark, textColor),
                const SizedBox(height: 20),
                if (_isDrawing)
                  Text(
                    '${widget.eligibleMembers.length} eligible members',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textSecondary,
                    ),
                  ),
                if (_winner != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Payout will be scheduled automatically.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlotDisplay(bool isDark, Color textColor) {
    final displayed = _winner ?? widget.eligibleMembers[_currentIndex];
    final isRevealed = _winner != null;

    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, child) {
        final scale = isRevealed ? 1.0 : (0.95 + 0.05 * _pulseCtrl.value);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: isRevealed
                  ? AppTheme.accentYellow.withValues(alpha: 0.15)
                  : (isDark
                      ? AppTheme.darkSurface
                      : AppTheme.backgroundLight),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isRevealed
                    ? AppTheme.accentYellow
                    : (isDark ? AppTheme.darkBorder : Colors.grey[300]!),
                width: isRevealed ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                if (isRevealed)
                  const Icon(Icons.star_rounded,
                      color: AppTheme.accentYellow, size: 28),
                if (isRevealed) const SizedBox(height: 6),
                Text(
                  _truncate(displayed),
                  style: TextStyle(
                    fontSize: isRevealed ? 20 : 18,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                    color: isRevealed ? AppTheme.accentYellow : textColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
