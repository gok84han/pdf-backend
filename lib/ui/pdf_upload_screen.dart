import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/api_error.dart';
import '../core/api_error_handler.dart';
import '../features/pdf/pdf_analyze_service.dart';
import '../features/pdf/pdf_meta_service.dart';
import 'result_screen.dart';
import 'upgrade_screen.dart';

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
  bool get _isLoading => _requestState == AnalyzeRequestState.loading;

  Future<void> _pickAndUpload() async {
    setState(() {
      _requestState = AnalyzeRequestState.idle;
      _phase = '';
    });

    debugPrint("PICKER_START");
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    debugPrint("PICKER_DONE result_null=${picked == null}");

    if (picked == null) {
      return;
    }

    final filePath = picked.files.single.path;
    if (filePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid file')),
      );
      setState(() {
        _requestState = AnalyzeRequestState.error;
      });
      return;
    }

    setState(() {
      _requestState = AnalyzeRequestState.loading;
      _phase = 'Uploading...';
    });

    try {
      final file = File(filePath);
      final client = ApiClient();
      late final Map<String, dynamic> result;

      setState(() {
        _phase = 'Analyzing...';
      });

      if (widget.mode == PdfUploadMode.meta) {
        result = await PdfMetaService(client).fetchMeta(file);
      } else {
        debugPrint("ANALYZE_START path=${filePath}");
        result = await PdfAnalyzeService(client).analyze(file);
      }

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
      if (widget.mode == PdfUploadMode.analyze &&
          e.code == ApiErrorCode.QUOTA_EXCEEDED) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aylık ücretsiz limit doldu')),
        );
        setState(() {
          _requestState = AnalyzeRequestState.error;
          _phase = '';
        });
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const UpgradeScreen(),
          ),
        );
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

  @override
  Widget build(BuildContext context) {
    final title = widget.mode == PdfUploadMode.meta ? 'PDF Meta' : 'Analyze PDF';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: _isLoading ? null : _pickAndUpload,
                child: const Text('Select PDF'),
              ),
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
