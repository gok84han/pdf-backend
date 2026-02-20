import 'dart:io';

import 'package:http/http.dart' as http;

import '../auth/auth_state.dart';

class ApiClient {
  ApiClient({
    this.baseUrl = 'http://10.0.2.2:8787',
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _httpClient;

  Future<http.Response> analyzePdf(File pdf) async {
    final String? idToken = await loadToken();
    final Uri uri = Uri.parse('$baseUrl/analyze-pdf');

    final http.MultipartRequest request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer ${idToken ?? ""}'
      ..files.add(await http.MultipartFile.fromPath('file', pdf.path));

    final http.StreamedResponse streamed = await _httpClient.send(request);
    return http.Response.fromStream(streamed);
  }
}
