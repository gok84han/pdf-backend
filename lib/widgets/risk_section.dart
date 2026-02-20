import 'package:flutter/material.dart';

import '../models/pdf_analysis_response.dart';
import 'risk_item_card.dart';

class RiskSection extends StatelessWidget {
  final List<RiskItem> items;

  const RiskSection({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'S\u00F6zle\u015Fme Riskleri',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          for (final item in items) RiskItemCard(item: item),
        ],
      ),
    );
  }
}
