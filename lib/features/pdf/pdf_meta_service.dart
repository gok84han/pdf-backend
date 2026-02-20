import 'dart:io';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/api_error_mapper.dart';

class PdfMetaService {
  final ApiClient _client;

  PdfMetaService(this._client);

  Future<Map<String, dynamic>> fetchMeta(File pdf) async {
    try {
      return await _client.postPdfMeta(pdf);
    } on Exception catch (e) {
      final ApiError apiError = mapToApiError(e);
      throw apiError;
    }
  }
}