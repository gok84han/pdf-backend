import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
    // BASE URL (LOCKED)
    // Android Emulator uses 10.0.2.2 to access host machine
    // Real device can use 127.0.0.1 only with adb reverse
    // Do NOT change this unless backend connectivity is intentionally modified
    static const String _baseUrl = 'http://10.215.29.41:8787';


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

  Future<String?> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('id_token');
  }

  Future<Map<String, String>> _authHeaders([Map<String, String>? existing]) async {
    final headers = <String, String>{...?existing};
    final token = await loadToken();
    if (token == null || token.isEmpty) {
      return headers;
    }
    headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  Future<Map<String, dynamic>> getMe() async {
    final headers = await _authHeaders();
    final response = await _client.get(Uri.parse('$_baseUrl/me'), headers: headers);
    _ensureSuccess(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> postPdfMeta(File pdf) async {
    final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/pdf/meta'));
    request.files.add(await http.MultipartFile.fromPath('file', pdf.path));
    final headers = await _authHeaders(request.headers);
    request.headers.addAll(headers);
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    _ensureSuccess(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> postAnalyzePdf(File pdf) async {
    final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/analyze-pdf'));
    request.files.add(await http.MultipartFile.fromPath('file', pdf.path));
    final headers = await _authHeaders(request.headers);
    request.headers.addAll(headers);
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    _ensureSuccess(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> activateProPlan() async {
    final uri = Uri.parse('$_baseUrl/plan/activate');
    final headers = await _authHeaders(<String, String>{
      'Content-Type': 'application/json',
    });
    final response = await _client.post(
      uri,
      headers: headers,
      body: jsonEncode(<String, String>{'plan': 'pro'}),
    );
    _ensureSuccess(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
