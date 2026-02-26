import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:pdf/core/config.dart';

class AnalyzeService {
  AnalyzeService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

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

  Future<({int status, String body})> analyzePdf(File pdfFile, String jwt) async {
    final url = '${AppConfig.baseUrl}/analyze-pdf';
    final filePath = pdfFile.path;
    final fileSize = await pdfFile.length();
    final fileName = filePath.split(Platform.pathSeparator).last;
    final authPreview = jwt.substring(0, jwt.length < 12 ? jwt.length : 12);

    print('STEP5: POST /analyze-pdf url=$url');
    print('STEP5: file path=$filePath size=$fileSize name=$fileName');
    print('STEP5: auth=Bearer $authPreview...');

    final request = http.MultipartRequest('POST', Uri.parse(url));
    request.headers.addAll(<String, String>{
      'Authorization': 'Bearer $jwt',
      'Accept': 'application/json',
    });
    _logRequestDebug(method: 'POST', fullUrl: url, headers: request.headers);
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        filePath,
        filename: fileName,
        contentType: MediaType('application', 'pdf'),
      ),
    );

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    final bodySnippet = response.body.length > 400
        ? response.body.substring(0, 400)
        : response.body;

    print('STEP5: status=${response.statusCode}');
    print('STEP5: bodySnippet=$bodySnippet');

    return (status: response.statusCode, body: response.body);
  }
}
