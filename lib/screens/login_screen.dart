import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../auth/auth_state.dart';
import '../auth/google_auth_service.dart';
import '../ui/home_screen.dart';

class LoginScreen extends StatelessWidget {
  LoginScreen({super.key});

  final GoogleAuthService _googleAuthService = GoogleAuthService();
  static const String _googleAuthUrl = 'http://10.0.2.2:8787/auth/google';

  Future<void> _handleGoogleSignIn(BuildContext context) async {
    try {
      final String? idToken = await _googleAuthService.signIn();
      if (idToken == null) {
        debugPrint('Google Sign-In failed or canceled (idToken is null).');
        return;
      }

      final response = await http.post(
        Uri.parse(_googleAuthUrl),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken}),
      );
      if (!context.mounted) return;

      if (response.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Google giris hatasi (${response.statusCode})')),
        );
        return;
      }

      final Map<String, dynamic> json =
          jsonDecode(response.body) as Map<String, dynamic>;
      final String? token = json['token'] as String?;
      if (token == null || token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google giris hatasi')),
        );
        return;
      }

      await saveToken(token);
      if (!context.mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const HomeScreen(),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google giris hatasi')),
      );
      debugPrint('Google sign-in exchange failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () => _handleGoogleSignIn(context),
              child: const Text('Google ile giris'),
            ),
          ],
        ),
      ),
    );
  }
}
