import 'package:flutter/material.dart';

class EmptyRiskState extends StatelessWidget {
  const EmptyRiskState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(12),
      child: Text('Açık bir risk ifadesi tespit edilmedi.'),
    );
  }
}
