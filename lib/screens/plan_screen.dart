import 'package:flutter/material.dart';

import '../services/plan_selection_store.dart';
import '../subscription/plan_tier.dart';
import 'pro_screen.dart';

const String _freeTitle = 'FREE';
const String _proMonthlyTitle = 'PRO MONTHLY';
const String _proYearlyTitle = 'PRO YEARLY';

const String _freePrice = '\$0 / month';
const String _proMonthlyPrice = '\$12.99 / month';
const String _proYearlyPrice = '\$79.99 / year';

const String _badgeMostPopular = 'Most Popular';
const String _badgeBestValue = 'Best Value';
const String _badgeSelected = 'Selected';

const List<String> _freeFeatures = [
  '10 analyses per month',
  'Small document size limit',
  'Standard summary',
  'No advanced risk labeling',
];

const List<String> _proBaseFeatures = [
  '100 analyses per month',
  'Larger document size limit',
  'Risk labels included',
  'Priority processing',
  'Advanced AI analysis',
];

const List<String> _proYearlyFeatures = [
  ..._proBaseFeatures,
  'Save 48%',
];

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key, this.currentPlan});

  final PlanTier? currentPlan;

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  final PlanSelectionStore _store = PlanSelectionStore();
  PlanTier _selected = PlanTier.free;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSelected();
  }

  Future<void> _loadSelected() async {
    try {
      final selected = await _store.loadSelected();
      if (!mounted) return;
      setState(() {
        _selected = selected;
      });
    } catch (e) {
      debugPrint('Plan selection load failed: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectTier(PlanTier tier) async {
    if (_selected == tier) return;
    setState(() {
      _selected = tier;
    });
    try {
      await _store.saveSelected(tier);
    } catch (e) {
      debugPrint('Plan selection save failed: $e');
    }
  }

  bool _isCurrentPlan(PlanTier tier) => widget.currentPlan == tier;

  String _cardButtonText(PlanTier tier) {
    if (_isCurrentPlan(tier)) return 'Current Plan';
    if (widget.currentPlan != null) {
      return _selected == tier ? 'Selected' : 'Select';
    }
    if (tier == PlanTier.free) {
      return _selected == PlanTier.free ? 'Current Plan' : 'Select';
    }
    return _selected == tier ? 'Selected' : 'Select';
  }

  String _primaryActionText() {
    switch (_selected) {
      case PlanTier.free:
        return 'Continue with Free';
      case PlanTier.proMonthly:
        return 'Continue to Upgrade (Monthly)';
      case PlanTier.proYearly:
        return 'Continue to Upgrade (Yearly)';
    }
  }

  Future<void> _onContinue() async {
    if (_selected == PlanTier.free) {
      Navigator.of(context).pop();
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProScreen(selectedPlan: _selected),
      ),
    );
  }

  Widget _buildBadge({
    required String text,
    required Color backgroundColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildCurrentPlanBanner() {
    final currentPlan = widget.currentPlan;
    if (currentPlan == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Text(
        'Current Plan: ${planTierDisplayLabel(currentPlan)}',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.blue.shade900,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Widget _buildPlanCard({
    required PlanTier tier,
    required String title,
    required String price,
    required List<String> features,
    required Color buttonColor,
    Color? backgroundColor,
    String? badge,
  }) {
    final isSelected = _selected == tier;
    return Card(
      margin: EdgeInsets.zero,
      color: backgroundColor,
      elevation: isSelected ? 6 : 1,
      shadowColor: isSelected ? Colors.blue.withValues(alpha: 0.35) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? Colors.blue : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _selectTier(tier),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          price,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (isSelected)
                        _buildBadge(
                          text: _badgeSelected,
                          backgroundColor: Colors.blue,
                          textColor: Colors.white,
                        ),
                      if (isSelected && badge != null)
                        const SizedBox(height: 6),
                      if (badge != null)
                        _buildBadge(
                          text: badge,
                          backgroundColor: Colors.blue.shade100,
                          textColor: Colors.blue.shade800,
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...features.map(
                (feature) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.check, color: Colors.green, size: 18),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          feature,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _selectTier(tier),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(_cardButtonText(tier)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryButtonColor =
        _selected == PlanTier.free ? Colors.grey : Colors.blue;

    return Scaffold(
      appBar: AppBar(title: const Text('Choose Your Plan')),
      body: _isLoading
          ? const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Column(
                    children: [
                      _buildCurrentPlanBanner(),
                      _buildPlanCard(
                        tier: PlanTier.free,
                        title: _freeTitle,
                        price: _freePrice,
                        features: _freeFeatures,
                        buttonColor: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      _buildPlanCard(
                        tier: PlanTier.proMonthly,
                        title: _proMonthlyTitle,
                        price: _proMonthlyPrice,
                        badge: _badgeMostPopular,
                        backgroundColor:
                            const Color.fromRGBO(33, 150, 243, 0.08),
                        features: _proBaseFeatures,
                        buttonColor: Colors.blue,
                      ),
                      const SizedBox(height: 16),
                      _buildPlanCard(
                        tier: PlanTier.proYearly,
                        title: _proYearlyTitle,
                        price: _proYearlyPrice,
                        badge: _badgeBestValue,
                        features: _proYearlyFeatures,
                        buttonColor: Colors.blue,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _onContinue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryButtonColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(_primaryActionText()),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
