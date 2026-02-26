import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/core/config.dart';
import 'package:pdf/core/token_service.dart';

class ApiClient {
  ApiClient({
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

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

  Future<http.Response> analyzePdf(File pdf) async {
    final token = await TokenService.read();
    final Uri uri = Uri.parse('${AppConfig.baseUrl}/analyze-pdf');
    final http.MultipartRequest request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('file', pdf.path));
    if (token != null && token.isNotEmpty) {
      request.headers.addAll(<String, String>{
        'Authorization': 'Bearer $token',
      });
    }
    _logRequestDebug(
      method: 'POST',
      fullUrl: '${AppConfig.baseUrl}/analyze-pdf',
      headers: request.headers,
    );

    final http.StreamedResponse streamed = await _httpClient.send(request);
    return http.Response.fromStream(streamed);
  }
}
