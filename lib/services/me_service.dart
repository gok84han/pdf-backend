import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/core/config.dart';

import '../auth/auth_state.dart';

class MeInfo {
  MeInfo({
    required this.userId,
    required this.email,
    required this.limit,
    required this.used,
    required this.remaining,
    required this.remainingQuota,
  });

  final String userId;
  final String? email;
  final int limit;
  final int used;
  final int remaining;
  final int remainingQuota;

  factory MeInfo.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> quota =
        (json['quota'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};

    return MeInfo(
      userId: (json['user_id'] ?? '').toString(),
      email: json['email'] == null ? null : json['email'].toString(),
      limit: (quota['limit'] as num?)?.toInt() ?? 0,
      used: (quota['used'] as num?)?.toInt() ?? 0,
      remaining: (quota['remaining'] as num?)?.toInt() ?? 0,
      remainingQuota: (json['remainingQuota'] as num?)?.toInt() ??
          (quota['remaining'] as num?)?.toInt() ??
          0,
    );
  }
}

class MeService {
  MeService({
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

  Future<MeInfo> getMe() async {
    final String? idToken = await loadToken();

    final fullUrl = '${AppConfig.baseUrl}/me';
    final Uri uri = Uri.parse(fullUrl);
    final headers = <String, String>{
      'Authorization': 'Bearer ${idToken ?? ""}',
      'Accept': 'application/json',
    };
    _logRequestDebug(method: 'GET', fullUrl: fullUrl, headers: headers);
    final http.Response response = await _httpClient.get(
      uri,
      headers: headers,
    );
    final String bodySnippet = response.body.length > 120
        ? response.body.substring(0, 120)
        : response.body;
    print('ME_SERVICE: /me status=${response.statusCode}');
    print('ME_SERVICE: /me bodySnippet=$bodySnippet');

    if (response.statusCode != 200) {
      throw Exception('GET /me failed: ${response.statusCode}');
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('GET /me returned invalid JSON');
    }

    return MeInfo.fromJson(decoded);
  }
}
