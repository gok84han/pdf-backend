import 'package:flutter/material.dart';

import '../core/api_client.dart';
import 'home_screen.dart';

class UpgradeScreen extends StatelessWidget {
  const UpgradeScreen({super.key});

  Future<void> _activatePro(BuildContext context) async {
    try {
      await ApiClient().activateProPlan();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pro aktif')),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upgrade')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Premium plan - Yakinda'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {},
                child: const Text('See plans'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => _activatePro(context),
                child: const Text('Activate Pro (debug)'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Later'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
