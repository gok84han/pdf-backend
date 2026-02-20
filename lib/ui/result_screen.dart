import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ResultScreen extends StatefulWidget {
  final Map<String, dynamic> result;

  const ResultScreen({super.key, required this.result});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  List<bool> _actionChecked = const [];

  void _syncActionState(int length) {
    if (_actionChecked.length != length) {
      _actionChecked = List<bool>.filled(length, false);
    }
  }

  IconData _riskIcon(String type) {
    return switch (type) {
      'unilateral_obligation' => Icons.balance,
      'penalty_clause' => Icons.warning_amber_rounded,
      'auto_renewal' => Icons.visibility,
      'jurisdiction_arbitration' => Icons.gavel,
      'data_processing' => Icons.privacy_tip_outlined,
      _ => Icons.label_outline,
    };
  }

  @override
  Widget build(BuildContext context) {
    final hasSummary = widget.result.containsKey('summary');
    final hasActions = widget.result.containsKey('actions');
    final summary = widget.result['summary']?.toString() ?? '';
    final actions = (widget.result['actions'] as List?) ?? const [];
    final disclaimerShort = widget.result['disclaimer_short']?.toString() ?? '';
    final riskLabels = (widget.result['riskLabels'] as List?) ?? const [];
    final hasRiskLabels = riskLabels.isNotEmpty;

    if (hasActions) {
      _syncActionState(actions.length);
    }

    if (hasSummary || hasActions || disclaimerShort.isNotEmpty || widget.result.containsKey('riskLabels')) {
      return Scaffold(
        appBar: AppBar(title: const Text('Result')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (disclaimerShort.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(disclaimerShort),
              ),
              const SizedBox(height: 16),
            ],
            if (hasSummary) ...[
              const Text('\u00d6zet'),
              Row(
                children: [
                  TextButton(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: summary));
                    },
                    child: const Text('Kopyala'),
                  ),
                ],
              ),
              SelectableText(summary),
              if (hasActions) const SizedBox(height: 16),
            ],
            if (hasActions)
              ...List.generate(actions.length, (index) {
                final item = actions[index];
                String title;
                if (item is Map && item['title'] != null) {
                  title = item['title'].toString();
                } else {
                  title = item.toString();
                }
                return CheckboxListTile(
                  value: _actionChecked[index],
                  onChanged: (value) {
                    setState(() {
                      _actionChecked[index] = value ?? false;
                    });
                  },
                  title: Text(title),
                );
              }),
            const SizedBox(height: 16),
            const Text('Risk Etiketleri'),
            const SizedBox(height: 8),
            if (!hasRiskLabels)
              const Text('Pro ile acilir')
            else
              ...List.generate(riskLabels.length, (index) {
                final item = riskLabels[index];
                if (item is! Map) return const SizedBox.shrink();
                final type = item['type']?.toString() ?? '';
                final title = item['title']?.toString() ?? type;
                final excerpt = item['excerpt']?.toString() ?? '';
                final note = item['note']?.toString() ?? '';
                final confidence = item['confidence']?.toString() ?? '';
                return Card(
                  child: ListTile(
                    leading: Icon(_riskIcon(type)),
                    title: Text(title),
                    subtitle: Text(
                      '$excerpt\n$note${confidence.isEmpty ? '' : '\nConfidence: $confidence'}',
                    ),
                    isThreeLine: true,
                  ),
                );
              }),
          ],
        ),
      );
    }

    final pretty = const JsonEncoder.withIndent('  ').convert(widget.result);
    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Text(pretty),
      ),
    );
  }
}


