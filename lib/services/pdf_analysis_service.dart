import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/pdf_analysis_response.dart';

class PdfAnalysisService {
  final String baseUrl;
  final http.Client _client;

  PdfAnalysisService({
    this.baseUrl = 'http://10.0.2.2:8787',
    http.Client? client,
  }) : _client = client ?? http.Client();

  Future<PdfAnalysisResponse> analyzePdf(File pdfFile) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/analyze-pdf'),
      );
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
