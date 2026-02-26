import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:pdf/core/config.dart';
import 'package:pdf/core/token_service.dart';

class ApiClient {
  final http.Client _client;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  void _ensureSuccess(http.Response response) {
    if (response.statusCode == 401) {
      throw Exception('HTTP_401: ${response.body}');
    }
    if (response.statusCode != 200) {
      throw Exception('HTTP_${response.statusCode}: ${response.body}');
    }
  }

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

  Future<Map<String, String>> _authHeaders([Map<String, String>? existing]) async {
    final headers = <String, String>{...?existing};
    final token = await TokenService.read();
    if (token == null || token.isEmpty) {
      return headers;
    }
    headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  Future<Map<String, dynamic>> getMe() async {
    final fullUrl = '${AppConfig.baseUrl}/me';
    final headers = await _authHeaders(<String, String>{
      'Accept': 'application/json',
    });
    _logRequestDebug(method: 'GET', fullUrl: fullUrl, headers: headers);
    final response = await _client.get(Uri.parse(fullUrl), headers: headers);
    final bodySnippet = response.body.length > 120
        ? response.body.substring(0, 120)
        : response.body;
    print('API_CLIENT: /me status=${response.statusCode}');
    print('API_CLIENT: /me bodySnippet=$bodySnippet');
    _ensureSuccess(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> postPdfMeta(File pdf) async {
    final fullUrl = '${AppConfig.baseUrl}/pdf/meta';
    final request = http.MultipartRequest('POST', Uri.parse(fullUrl));
    request.files.add(await http.MultipartFile.fromPath('file', pdf.path));
    final headers = await _authHeaders(request.headers);
    request.headers.addAll(headers);
    _logRequestDebug(method: 'POST', fullUrl: fullUrl, headers: request.headers);
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    _ensureSuccess(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> postAnalyzePdf(File pdf) async {
    final url = '${AppConfig.baseUrl}/analyze-pdf';
    final token = await TokenService.read();
    final authPreview = token == null || token.isEmpty
        ? 'Bearer <missing>'
        : 'Bearer ${token.substring(0, token.length < 10 ? token.length : 10)}...';
    final filename = pdf.path.split(Platform.pathSeparator).last;
    final bytes = await pdf.length();
    print('STEP5: POST /analyze-pdf url=$url');
    print('STEP5: authHeader=$authPreview');
    print('STEP5: multipart field=file filename=$filename bytes=$bytes');
    final request = http.MultipartRequest('POST', Uri.parse(url));
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        pdf.path,
        filename: filename,
        contentType: MediaType('application', 'pdf'),
      ),
    );
    final headers = await _authHeaders(request.headers);
    request.headers.addAll(headers);
    _logRequestDebug(method: 'POST', fullUrl: url, headers: request.headers);
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final bodySnippet = response.body.length > 400
        ? response.body.substring(0, 400)
        : response.body;
    print('STEP5: /analyze-pdf status=${response.statusCode}');
    print('STEP5: /analyze-pdf bodySnippet=$bodySnippet');
    if (response.statusCode != 200) {
      throw Exception('STEP5 FAIL: status=${response.statusCode} body=$bodySnippet');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> activateProPlan() async {
    final fullUrl = '${AppConfig.baseUrl}/plan/activate';
    final uri = Uri.parse(fullUrl);
    final headers = await _authHeaders(<String, String>{
      'Content-Type': 'application/json',
    });
    _logRequestDebug(method: 'POST', fullUrl: fullUrl, headers: headers);
    final response = await _client.post(
      uri,
      headers: headers,
      body: jsonEncode(<String, String>{'plan': 'pro'}),
    );
    _ensureSuccess(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
