import 'dart:io';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/api_error_mapper.dart';

class PdfAnalyzeService {
  final ApiClient _client;

  PdfAnalyzeService(this._client);

  Future<Map<String, dynamic>> analyze(File pdf) async {
    try {
      return await _client.postAnalyzePdf(pdf);
    } on Exception catch (e) {
      final ApiError apiError = mapToApiError(e);
      throw apiError;
    }
  }
}