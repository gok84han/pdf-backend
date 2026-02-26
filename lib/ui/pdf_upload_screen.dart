import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdf/core/token_service.dart';

import '../core/api_client.dart';
import '../core/api_error.dart';
import '../core/api_error_handler.dart';
import '../features/pdf/pdf_meta_service.dart';
import '../services/analyze_service.dart';
import 'result_screen.dart';

enum PdfUploadMode { meta, analyze }

enum AnalyzeRequestState { idle, loading, success, error }

class PdfUploadScreen extends StatefulWidget {
  final PdfUploadMode mode;

  const PdfUploadScreen({super.key, required this.mode});

  @override
  State<PdfUploadScreen> createState() => _PdfUploadScreenState();
}

class _PdfUploadScreenState extends State<PdfUploadScreen> {
  AnalyzeRequestState _requestState = AnalyzeRequestState.idle;
  String _phase = '';
  File? _selectedPdfFile;
  String _selectedPdfInfo = '';
  String _analyzeResponseText = '';

  bool get _isLoading => _requestState == AnalyzeRequestState.loading;

  String _buildDisplayText(String resultText) {
    final trimmed = resultText.trimLeft();
    final looksLikeJson =
        trimmed.startsWith('{') || resultText.contains('"disclaimer_short"');
    if (!looksLikeJson) {
      return resultText;
    }

    try {
      final decoded = jsonDecode(resultText);
      if (decoded is! Map) {
        return resultText;
      }

      final data = Map<String, dynamic>.from(decoded);

      String mainText = '';
      if (data['executive_snapshot'] != null) {
        mainText = data['executive_snapshot'].toString();
      } else if (data['analysis'] != null) {
        mainText = data['analysis'].toString();
      } else if (data['text'] != null) {
        mainText = data['text'].toString();
      } else {
        mainText = resultText;
      }

      final discShort = (data['disclaimer_short'] ?? '').toString();
      final discLong = (data['disclaimer_long'] ?? '').toString();

      final displayText = '${mainText.trim()}\n\n'
          '${discShort.isNotEmpty ? '${discShort.trim()}\n' : ''}'
          '${discLong.isNotEmpty ? discLong.trim() : ''}';
      return displayText.trimRight();
    } catch (_) {
      return resultText;
    }
  }

  List<InlineSpan> buildFormattedSpans(String text) {
    final normalizedText = text.replaceAll('\\n', '\n');
    final lines = normalizedText.split('\n');
    final spans = <InlineSpan>[];
    const headingStyle = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: Colors.black,
    );
    const bodyStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.normal,
      color: Colors.black,
    );
    const disclaimerStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: Colors.black,
    );

    bool isHeading(String value) {
      const knownHeadings = ['EXECUTIVE SNAPSHOT', 'KEY POINTS', 'DOCUMENT'];
      if (knownHeadings.any((h) => value.startsWith(h))) {
        return true;
      }

      final allCapsPattern = RegExp(r'^[A-Z0-9][A-Z0-9\s\-:&/()]*$');
      return allCapsPattern.hasMatch(value) && value.contains(RegExp(r'[A-Z]'));
    }

    String normalizeForCheck(String value) {
      return value
          .toLowerCase()
          .replaceAll('\u00e7', 'c')
          .replaceAll('\u011f', 'g')
          .replaceAll('\u0131', 'i')
          .replaceAll('\u00f6', 'o')
          .replaceAll('\u015f', 's')
          .replaceAll('\u00fc', 'u');
    }

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        spans.add(const TextSpan(text: '\n'));
        continue;
      }

      final normalized = normalizeForCheck(trimmed);
      if (normalized.startsWith('bu icerik hukuki') ||
          normalized.startsWith('bu cikti hukuki')) {
        spans.add(const TextSpan(text: '\n\n'));
        spans.add(
          TextSpan(
            text: '$trimmed\n',
            style: disclaimerStyle,
          ),
        );
        continue;
      }

      if (isHeading(trimmed)) {
        spans.add(
          TextSpan(
            text: '$trimmed\n\n',
            style: headingStyle,
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: '$line\n',
            style: bodyStyle,
          ),
        );
      }
    }

    return spans;
  }

  Future<({File file, String info})?> _pickPdf() async {
    debugPrint('PICKER_START');
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    debugPrint('PICKER_DONE result_null=${picked == null}');

    if (picked == null) {
      return null;
    }

    final filePath = picked.files.single.path;
    if (filePath == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid file')),
        );
      }
      return null;
    }

    final file = File(filePath);
    final fileSize = await file.length();
    print('STEP5: pdfSelected path=$filePath size=$fileSize');
    return (file: file, info: 'path=$filePath size=$fileSize');
  }

  Future<void> _pickAndUploadMeta() async {
    setState(() {
      _requestState = AnalyzeRequestState.idle;
      _phase = '';
    });

    final picked = await _pickPdf();
    if (picked == null) {
      return;
    }

    setState(() {
      _requestState = AnalyzeRequestState.loading;
      _phase = 'Uploading...';
    });

    try {
      final client = ApiClient();
      setState(() {
        _phase = 'Analyzing...';
      });
      final result = await PdfMetaService(client).fetchMeta(picked.file);

      if (!mounted) {
        return;
      }

      setState(() {
        _requestState = AnalyzeRequestState.success;
        _phase = '';
      });

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ResultScreen(result: result),
        ),
      );
    } on ApiError catch (e) {
      if (!mounted) {
        return;
      }
      handleApiErrorWithSnack(context, e);
      setState(() {
        _requestState = AnalyzeRequestState.error;
        _phase = '';
      });
    } on Exception catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
      setState(() {
        _requestState = AnalyzeRequestState.error;
        _phase = '';
      });
    } finally {
      if (!mounted) {
        return;
      }
      if (_requestState == AnalyzeRequestState.loading) {
        setState(() {
          _requestState = AnalyzeRequestState.idle;
          _phase = '';
        });
      }
    }
  }

  Future<void> _selectPdfForAnalyze() async {
    final picked = await _pickPdf();
    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _selectedPdfFile = picked.file;
      _selectedPdfInfo = picked.info;
      _analyzeResponseText = '';
    });
  }

  Future<void> _analyzeSelectedPdf() async {
    if (_selectedPdfFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a PDF first')),
      );
      return;
    }

    setState(() {
      _requestState = AnalyzeRequestState.loading;
      _phase = 'Analyzing...';
    });

    try {
      final jwt = await TokenService.read() ?? '';
      final response =
          await AnalyzeService().analyzePdf(_selectedPdfFile!, jwt);
      if (!mounted) {
        return;
      }

      final bodySnippet = response.body.length > 400
          ? response.body.substring(0, 400)
          : response.body;

      setState(() {
        _requestState = response.status == 200
            ? AnalyzeRequestState.success
            : AnalyzeRequestState.error;
        _phase = '';
        _analyzeResponseText = response.status == 200
            ? _buildDisplayText(response.body)
            : 'STEP5 FAIL: status=${response.status} body=$bodySnippet';
      });

      if (response.status == 200) {
        print('STEP5 OK: responseRendered=true');
      }
    } on Exception catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _requestState = AnalyzeRequestState.error;
        _phase = '';
        _analyzeResponseText = 'STEP5 FAIL: status=500 body=$e';
      });
    } finally {
      if (!mounted) {
        return;
      }
      if (_requestState == AnalyzeRequestState.loading) {
        setState(() {
          _requestState = AnalyzeRequestState.idle;
          _phase = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title =
        widget.mode == PdfUploadMode.meta ? 'PDF Meta' : 'Analyze PDF';
    final borderedButtonStyle = ElevatedButton.styleFrom(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(
          color: Colors.red,
          width: 1.5,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (widget.mode == PdfUploadMode.meta)
                ElevatedButton(
                  onPressed: _isLoading ? null : _pickAndUploadMeta,
                  child: const Text('Select PDF'),
                ),
              if (widget.mode == PdfUploadMode.analyze) ...[
                ElevatedButton(
                  onPressed: _isLoading ? null : _selectPdfForAnalyze,
                  style: borderedButtonStyle,
                  child: const Text('Select PDF'),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.red,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(_selectedPdfInfo.isEmpty
                      ? 'No PDF selected'
                      : _selectedPdfInfo),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _analyzeSelectedPdf,
                  style: borderedButtonStyle,
                  child: const Text('Analyze'),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.red,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SingleChildScrollView(
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black,
                          ),
                          children: buildFormattedSpans(_analyzeResponseText),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (_isLoading) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 8),
                Text(_phase),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
