import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/core/config.dart';
import 'package:pdf/core/token_service.dart';

import '../models/pdf_analysis_response.dart';

class PdfAnalysisService {
  final http.Client _client;

  PdfAnalysisService({
    http.Client? client,
  }) : _client = client ?? http.Client();

  void _logRequestDebug({
    required String method,
    required String fullUrl,
    required Map<String, String> headers,
  }) {
    final authHeader = headers['Authorization'] ?? '';
    final hasAuthHeader = authHeader.startsWith('Bearer ');
    final token = hasAuthHeader ? authHeader.substring(7).trim() : '';
    final tokenParts = token.isEmpty ? 0 : token.split('.').length;
    final tokenLen = token.length;
    debugPrint(
      'HTTPDBG fullUrl=$fullUrl method=$method hasAuthHeader=$hasAuthHeader tokenParts=$tokenParts tokenLen=$tokenLen',
    );
    if (tokenParts != 0 && tokenParts != 3) {
      debugPrint('HTTPDBG INVALID TOKEN FORMAT');
      throw Exception('INVALID TOKEN FORMAT');
    }
  }

  Future<PdfAnalysisResponse> analyzePdf(File pdfFile) async {
    try {
      final token = await TokenService.read();
      final fullUrl = '${AppConfig.baseUrl}/analyze-pdf';
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(fullUrl),
      );
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      _logRequestDebug(method: 'POST', fullUrl: fullUrl, headers: request.headers);
      request.files.add(
        await http.MultipartFile.fromPath('file', pdfFile.path),
      );

      final streamedResponse = await _client.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw Exception('HTTP_${response.statusCode}: ${response.body}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return PdfAnalysisResponse.fromJson(json);
    } catch (e) {
      throw Exception('PDF_ANALYSIS_FAILED: $e');
    }
  }
}
