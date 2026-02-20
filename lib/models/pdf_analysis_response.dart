class PdfAnalysisResponse {
  final String detectedLanguage;
  final String documentType;
  final Summary summary;
  final List<String> keyPoints;
  final List<ActionItem> actions;
  final RiskAnalysis riskAnalysis;

  const PdfAnalysisResponse({
    required this.detectedLanguage,
    required this.documentType,
    required this.summary,
    required this.keyPoints,
    required this.actions,
    required this.riskAnalysis,
  });

  factory PdfAnalysisResponse.fromJson(Map<String, dynamic> json) {
    return PdfAnalysisResponse(
      detectedLanguage: (json['detected_language'] as String?) ?? '',
      documentType: (json['document_type'] as String?) ?? 'unknown',
      summary: Summary.fromJson(_asMap(json['summary'])),
      keyPoints: _asList(
        json['key_points'],
      ).map((item) => item.toString()).toList(growable: false),
      actions: _asList(json['actions'])
          .map((item) => ActionItem.fromJson(_asMap(item)))
          .toList(growable: false),
      riskAnalysis: RiskAnalysis.fromJson(_asMap(json['risk_analysis'])),
    );
  }
}

class Summary {
  final List<SummarySection> sections;

  const Summary({required this.sections});

  factory Summary.fromJson(Map<String, dynamic> json) {
    return Summary(
      sections: _asList(json['sections'])
          .map((item) => SummarySection.fromJson(_asMap(item)))
          .toList(growable: false),
    );
  }
}

class SummarySection {
  final String title;
  final String content;

  const SummarySection({required this.title, required this.content});

  factory SummarySection.fromJson(Map<String, dynamic> json) {
    return SummarySection(
      title: (json['title'] as String?) ?? '',
      content: (json['content'] as String?) ?? '',
    );
  }
}

class ActionItem {
  final String id;
  final String text;

  const ActionItem({required this.id, required this.text});

  factory ActionItem.fromJson(Map<String, dynamic> json) {
    return ActionItem(
      id: (json['id'] as String?) ?? '',
      text: (json['text'] as String?) ?? '',
    );
  }
}

class RiskAnalysis {
  final bool enabled;
  final List<RiskItem> items;

  const RiskAnalysis({required this.enabled, required this.items});

  factory RiskAnalysis.fromJson(Map<String, dynamic> json) {
    return RiskAnalysis(
      enabled: (json['enabled'] as bool?) ?? false,
      items: _asList(
        json['items'],
      ).map((item) => RiskItem.fromJson(_asMap(item))).toList(growable: false),
    );
  }
}

class RiskItem {
  final String label;
  final String excerpt;
  final String reason;

  const RiskItem({
    required this.label,
    required this.excerpt,
    required this.reason,
  });

  factory RiskItem.fromJson(Map<String, dynamic> json) {
    return RiskItem(
      label: (json['label'] as String?) ?? '',
      excerpt: (json['excerpt'] as String?) ?? '',
      reason: (json['reason'] as String?) ?? '',
    );
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return const <String, dynamic>{};
}

List<dynamic> _asList(dynamic value) {
  if (value is List) {
    return value;
  }
  return const <dynamic>[];
}
