import 'package:flutter/material.dart';
import 'package:pdf/core/token_service.dart';

import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final t = await TokenService.read();
  print('BOOT token exists? ${t != null && t.isNotEmpty}');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: GoogleLoginScreen(),
    );
  }
}
