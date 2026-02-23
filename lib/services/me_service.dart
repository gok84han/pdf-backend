import 'dart:convert';

import 'package:http/http.dart' as http;

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
    this.baseUrl = 'http://10.215.29.41:8787',
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _httpClient;

  Future<MeInfo> getMe() async {
    final String? idToken = await loadToken();

    final Uri uri = Uri.parse('$baseUrl/me');
    final http.Response response = await _httpClient.get(
      uri,
      headers: <String, String>{
        'Authorization': 'Bearer ${idToken ?? ""}',
      },
    );

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
