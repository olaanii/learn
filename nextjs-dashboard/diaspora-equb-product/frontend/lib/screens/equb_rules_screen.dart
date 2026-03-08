import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../services/api_client.dart';
import '../services/app_snackbar_service.dart';
import '../providers/auth_provider.dart';
import '../services/wallet_service.dart';
import '../widgets/desktop_layout.dart';

class EqubRulesScreen extends StatefulWidget {
  final String equbId;
  final bool embeddedDesktop;

  const EqubRulesScreen({
    super.key,
    required this.equbId,
    this.embeddedDesktop = false,
  });

  @override
  State<EqubRulesScreen> createState() => _EqubRulesScreenState();
}

class _EqubRulesScreenState extends State<EqubRulesScreen> {
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isLoading = true;
  bool _isCreator = false;

  final _gracePeriodController = TextEditingController();
  final _lateFeeController = TextEditingController();
  final _roundDurationController = TextEditingController();

  int _selectedTypeIndex = 0;
  int _selectedFrequencyIndex = 1;
  int _selectedPayoutIndex = 0;
  double _penaltySeverity = 5;

  static const _equbTypeLabels = [
    'Finance', 'House', 'Car', 'Travel', 'Special',
    'Workplace', 'Education', 'Wedding', 'Emergency',
  ];
  static const _equbTypeIcons = [
    Icons.account_balance_rounded,
    Icons.home_rounded,
    Icons.directions_car_rounded,
    Icons.flight_rounded,
    Icons.star_rounded,
    Icons.work_rounded,
    Icons.school_rounded,
    Icons.favorite_rounded,
    Icons.local_hospital_rounded,
  ];
  static const _frequencyLabels = ['Daily', 'Weekly', 'Bi-Weekly', 'Monthly'];
  static const _frequencyDurations = ['24h cycles', '7-day cycles', '14-day cycles', '30-day cycles'];
  static const _payoutLabels = ['Lottery', 'Rotation', 'Bid'];
  static const _payoutDescriptions = [
    'Random winner each round',
    'Fixed order rotation',
    'Members bid for payout',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRules());
  }

  @override
  void dispose() {
    _gracePeriodController.dispose();
    _lateFeeController.dispose();
    _roundDurationController.dispose();
    super.dispose();
  }

  Future<void> _loadRules() async {
    final api = context.read<ApiClient>();
    final auth = context.read<AuthProvider>();
    final wallet = context.read<WalletService>();

    try {
      final data = await api.getEqubRules(widget.equbId);
      if (!mounted) return;

      final pool = context.read<ApiClient>();
      Map<String, dynamic>? poolData;
      try {
        final resp = await pool.getPool(widget.equbId);
        poolData = resp;
      } catch (_) {}

      final createdBy = poolData?['createdBy']?.toString().toLowerCase() ?? '';
      final myAddr = (wallet.walletAddress ?? auth.walletAddress ?? '').toLowerCase();
      final isCreator = createdBy.isNotEmpty &&
          createdBy != '0x0000000000000000000000000000000000000000' &&
          myAddr.isNotEmpty &&
          createdBy == myAddr;

      setState(() {
        _isCreator = isCreator;
        _selectedTypeIndex = (data['equbType'] as num?)?.toInt() ?? 0;
        _selectedFrequencyIndex = (data['frequency'] as num?)?.toInt() ?? 1;
        _selectedPayoutIndex = (data['payoutMethod'] as num?)?.toInt() ?? 0;
        _penaltySeverity = ((data['penaltySeverity'] as num?)?.toDouble() ?? 5).clamp(1, 10);
        _gracePeriodController.text =
            ((data['gracePeriodSeconds'] as num?)?.toInt() ?? 86400) ~/ 3600 > 0
                ? '${((data['gracePeriodSeconds'] as num?)?.toInt() ?? 86400) ~/ 3600}'
                : '24';
        _lateFeeController.text = '${(data['lateFeePercent'] as num?)?.toInt() ?? 0}';
        _roundDurationController.text =
            '${((data['roundDurationSeconds'] as num?)?.toInt() ?? 2592000) ~/ 86400}';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppSnackbarService.instance.error(
        message: 'Failed to load rules: $e',
        dedupeKey: 'rules_load_error',
      );
    }
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);

    final api = context.read<ApiClient>();
    final gracePeriodHours = int.tryParse(_gracePeriodController.text) ?? 24;
    final roundDurationDays = int.tryParse(_roundDurationController.text) ?? 30;

    try {
      await api.updateEqubRules(
        poolId: widget.equbId,
        rules: {
          'equbType': _selectedTypeIndex,
          'frequency': _selectedFrequencyIndex,
          'payoutMethod': _selectedPayoutIndex,
          'gracePeriodSeconds': gracePeriodHours * 3600,
          'penaltySeverity': _penaltySeverity.toInt(),
          'roundDurationSeconds': roundDurationDays * 86400,
          'lateFeePercent': int.tryParse(_lateFeeController.text) ?? 0,
        },
      );

      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _isEditing = false;
      });
      AppSnackbarService.instance.success(
        message: 'Rules updated successfully!',
        dedupeKey: 'rules_save_success',
      );
      await _loadRules();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppSnackbarService.instance.error(
        message: 'Failed to save rules: $e',
        dedupeKey: 'rules_save_error',
        duration: const Duration(seconds: 5),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final embeddedDesktop = widget.embeddedDesktop && AppTheme.isDesktop(context);

    final body = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: embeddedDesktop
                ? EdgeInsets.zero
                : const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_isCreator && !_isEditing)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.accentYellow.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 18, color: AppTheme.accentYellowDark),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Only the pool creator (Danna) can edit these rules.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondaryColor(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_isEditing)
                  ..._buildEditForm(context)
                else
                  ..._buildReadOnly(context),
                const SizedBox(height: 24),
                if (_isEditing) _buildActionButtons(context),
              ],
            ),
          );

    if (embeddedDesktop) {
      return DesktopContent(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DesktopSectionTitle(
                    title: _isEditing ? 'Edit Rules' : 'Equb Rules',
                    subtitle: 'Review pool rules and edit them from the desktop workspace when creator access is available.',
                  ),
                ),
                if (_isCreator && !_isEditing && !_isLoading)
                  IconButton(
                    icon: const Icon(Icons.edit_rounded),
                    tooltip: 'Edit rules',
                    onPressed: () => setState(() => _isEditing = true),
                  ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: _loadRules,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(gradient: AppTheme.bgGradient(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(_isEditing ? 'Edit Rules' : 'Equb Rules'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
          actions: [
            if (_isCreator && !_isEditing && !_isLoading)
              IconButton(
                icon: const Icon(Icons.edit_rounded),
                tooltip: 'Edit rules',
                onPressed: () => setState(() => _isEditing = true),
              ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadRules,
            ),
          ],
        ),
        body: body,
      ),
    );
  }

  List<Widget> _buildReadOnly(BuildContext context) {
    final typeName = _selectedTypeIndex < _equbTypeLabels.length
        ? _equbTypeLabels[_selectedTypeIndex]
        : 'Unknown';
    final typeIcon = _selectedTypeIndex < _equbTypeIcons.length
        ? _equbTypeIcons[_selectedTypeIndex]
        : Icons.category_rounded;
    final freqName = _selectedFrequencyIndex < _frequencyLabels.length
        ? _frequencyLabels[_selectedFrequencyIndex]
        : 'Unknown';
    final payoutName = _selectedPayoutIndex < _payoutLabels.length
        ? _payoutLabels[_selectedPayoutIndex]
        : 'Unknown';

    return [
      _ruleCard(context, 'Equb Type', typeName, typeIcon),
      _ruleCard(context, 'Frequency', freqName, Icons.schedule_rounded),
      _ruleCard(context, 'Payout Method', payoutName, Icons.payments_rounded),
      _ruleCard(context, 'Grace Period', '${_gracePeriodController.text} hours', Icons.timer_rounded),
      _ruleCard(context, 'Round Duration', '${_roundDurationController.text} days', Icons.calendar_today_rounded),
      _ruleCard(context, 'Penalty Severity', '${_penaltySeverity.toInt()}/10', Icons.warning_rounded),
      _ruleCard(context, 'Late Fee', '${_lateFeeController.text}%', Icons.percent_rounded),
    ];
  }

  Widget _ruleCard(BuildContext context, String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
        boxShadow: AppTheme.subtleShadowFor(context),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.accentYellow.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: AppTheme.textPrimaryColor(context)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(value, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildEditForm(BuildContext context) {
    return [
      Text('Equb Type', style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 8),
      _buildTypeSelector(context),
      const SizedBox(height: 20),
      Text('Contribution Frequency', style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 8),
      _buildFrequencySelector(context),
      const SizedBox(height: 20),
      Text('Payout Method', style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 8),
      _buildPayoutSelector(context),
      const SizedBox(height: 20),
      Row(
        children: [
          Expanded(
            child: _buildTextField(context, 'Grace Period (hours)', _gracePeriodController,
                keyboardType: TextInputType.number),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildTextField(context, 'Round Duration (days)', _roundDurationController,
                keyboardType: TextInputType.number),
          ),
        ],
      ),
      const SizedBox(height: 16),
      _buildTextField(context, 'Late Fee (%)', _lateFeeController,
          keyboardType: TextInputType.number),
      const SizedBox(height: 16),
      Text('Penalty Severity', style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 8),
      Row(
        children: [
          Text('Low', style: Theme.of(context).textTheme.bodySmall),
          Expanded(
            child: Slider(
              value: _penaltySeverity,
              min: 1,
              max: 10,
              divisions: 9,
              label: _penaltySeverity.toInt().toString(),
              activeColor: AppTheme.accentYellowDark,
              onChanged: (v) => setState(() => _penaltySeverity = v),
            ),
          ),
          Text('High', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ];
  }

  Widget _buildTypeSelector(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(_equbTypeLabels.length, (i) {
        final isSelected = _selectedTypeIndex == i;
        return GestureDetector(
          onTap: () => setState(() => _selectedTypeIndex = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.buttonColor(context)
                  : AppTheme.cardColor(context),
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? null
                  : Border.all(color: AppTheme.textHintColor(context)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _equbTypeIcons[i],
                  size: 18,
                  color: isSelected
                      ? AppTheme.buttonTextColor(context)
                      : AppTheme.textSecondaryColor(context),
                ),
                const SizedBox(width: 6),
                Text(
                  _equbTypeLabels[i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? AppTheme.buttonTextColor(context)
                        : AppTheme.textSecondaryColor(context),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildFrequencySelector(BuildContext context) {
    return Column(
      children: List.generate(_frequencyLabels.length, (i) {
        final isSelected = _selectedFrequencyIndex == i;
        return GestureDetector(
          onTap: () => setState(() => _selectedFrequencyIndex = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.buttonColor(context).withValues(alpha: 0.1)
                  : AppTheme.cardColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppTheme.buttonColor(context)
                    : AppTheme.textHintColor(context),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                  size: 20,
                  color: isSelected
                      ? AppTheme.buttonColor(context)
                      : AppTheme.textTertiaryColor(context),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _frequencyLabels[i],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryColor(context),
                        ),
                      ),
                      Text(
                        _frequencyDurations[i],
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textTertiaryColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildPayoutSelector(BuildContext context) {
    return Row(
      children: List.generate(_payoutLabels.length, (i) {
        final isSelected = _selectedPayoutIndex == i;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedPayoutIndex = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(left: i > 0 ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.buttonColor(context)
                    : AppTheme.cardColor(context),
                borderRadius: BorderRadius.circular(12),
                border: isSelected
                    ? null
                    : Border.all(color: AppTheme.textHintColor(context)),
              ),
              child: Column(
                children: [
                  Text(
                    _payoutLabels[i],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppTheme.buttonTextColor(context)
                          : AppTheme.textPrimaryColor(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _payoutDescriptions[i],
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected
                          ? AppTheme.buttonTextColor(context).withValues(alpha: 0.7)
                          : AppTheme.textTertiaryColor(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTextField(BuildContext context, String label,
      TextEditingController controller, {TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(hintText: 'Enter $label'),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _handleSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.buttonColor(context),
              foregroundColor: AppTheme.buttonTextColor(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
            ),
            child: _isSaving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.buttonTextColor(context),
                    ),
                  )
                : const Text('Save Rules',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: () => setState(() => _isEditing = false),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
            ),
            child: const Text('Cancel'),
          ),
        ),
      ],
    );
  }
}
