import 'package:flutter/material.dart';

import '../screens/plan_screen.dart';
import '../services/me_service.dart';
import '../subscription/plan_tier.dart';
import 'pdf_upload_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<MeInfo> _meFuture;

  @override
  void initState() {
    super.initState();
    _meFuture = MeService().getMe();
  }

  void _openUpload(PdfUploadMode mode) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfUploadScreen(mode: mode),
      ),
    );
  }

  void _openPlans() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const PlanScreen(currentPlan: PlanTier.free),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FutureBuilder<MeInfo>(
              future: _meFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return const SizedBox.shrink();
                }
                return Text(
                  'Free analyzes left this month: ${snapshot.data!.remainingQuota}',
                );
              },
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _openUpload(PdfUploadMode.meta),
              child: const Text('PDF Meta'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _openUpload(PdfUploadMode.analyze),
              child: const Text('Analyze PDF'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _openPlans,
              child: const Text('View Plans'),
            ),
          ],
        ),
      ),
    );
  }
}
