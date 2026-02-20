import 'package:flutter/material.dart';

import '../models/pdf_analysis_response.dart';

class RiskItemCard extends StatelessWidget {
  final RiskItem item;

  const RiskItemCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            item.excerpt,
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 4),
          Text(item.reason),
        ],
      ),
    );
  }
}
