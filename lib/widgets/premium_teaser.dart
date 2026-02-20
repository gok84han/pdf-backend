import 'package:flutter/material.dart';

class PremiumTeaser extends StatelessWidget {
  final VoidCallback? onTap;

  const PremiumTeaser({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Text('⚠️ Sözleşmeler için risk etiketleme (Premium)'),
      ),
    );
  }
}
