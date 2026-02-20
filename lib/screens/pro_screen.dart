import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../subscription/plan_tier.dart';
import '../subscription/pro_plan_service.dart';

class ProScreen extends StatelessWidget {
  ProScreen({super.key, this.selectedPlan});

  final PlanTier? selectedPlan;
  final ProPlanService _service = ProPlanService();

  String _title() {
    if (selectedPlan == PlanTier.proMonthly) {
      return 'Pro Plan (Test) - Monthly';
    }
    if (selectedPlan == PlanTier.proYearly) {
      return 'Pro Plan (Test) - Yearly';
    }
    return 'Pro Plan (Test)';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title())),
      body: FutureBuilder<ProductDetailsResponse>(
        future: _service.fetchProducts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Failed to load products: ${snapshot.error}'),
              ),
            );
          }
          final response = snapshot.data;
          if (response == null) {
            return const Center(child: Text('No response from store.'));
          }
          if (response.productDetails.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No products found.\nNot found: ${response.notFoundIDs.join(', ')}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: response.productDetails.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = response.productDetails[index];
              return Card(
                child: ListTile(
                  title: Text(item.title),
                  subtitle: Text(item.id),
                  trailing: Text(item.price),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
