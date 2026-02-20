import 'package:flutter/material.dart';

import '../models/pdf_analysis_response.dart';
import '../widgets/empty_risk_state.dart';
import '../widgets/premium_teaser.dart';
import '../widgets/risk_section.dart';
import '../widgets/unknown_doc_notice.dart';

class PdfResultScreen extends StatelessWidget {
  final PdfAnalysisResponse analysis;

  const PdfResultScreen({super.key, required this.analysis});

  @override
  Widget build(BuildContext context) {
    final response = analysis;
    final isUnknown = response.documentType == 'unknown';
    final isContract = response.documentType == 'contract';

    return Scaffold(
      appBar: AppBar(title: const Text('PDF Sonucu')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '\u00D6zet',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (response.summary.sections.isEmpty)
                const Text('\u00D6zet bulunamad\u0131.')
              else
                for (final section in response.summary.sections) ...[
                  Text(
                    section.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(section.content),
                  const SizedBox(height: 12),
                ],
              const SizedBox(height: 8),
              if (isUnknown)
                const UnknownDocNotice()
              else if (isContract)
                if (response.riskAnalysis.enabled)
                  if (response.riskAnalysis.items.isNotEmpty)
                    RiskSection(items: response.riskAnalysis.items)
                  else
                    const EmptyRiskState()
                else
                  const PremiumTeaser(onTap: null),
              const Text(
                'Key Points',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (response.keyPoints.isEmpty)
                const Text('Madde bulunamad\u0131.')
              else
                for (final point in response.keyPoints) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('- '),
                      Expanded(child: Text(point)),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              const SizedBox(height: 8),
              const Text(
                'Actions',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (response.actions.isEmpty)
                const Text('Aksiyon bulunamad\u0131.')
              else
                for (final action in response.actions)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: false,
                    onChanged: null,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(action.text),
                    subtitle: Text(action.id),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
