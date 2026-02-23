import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../auth/auth_state.dart';
import '../auth/google_auth_service.dart' show kServerClientId;
import '../ui/home_screen.dart';

class LoginScreen extends StatelessWidget {
  LoginScreen({super.key});

  static const String _googleAuthUrl = 'https://pdf-backend-waba.onrender.com/auth/google';

  Future<void> _handleGoogleSignIn(BuildContext context) async {
    try {
      debugPrint('LOGIN: pressed');
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: const <String>['openid', 'email'],
        serverClientId: kServerClientId,
      );
      debugPrint('LOGIN: before googleSignIn.signIn');
      final GoogleSignInAccount? account = await googleSignIn.signIn();
      debugPrint('LOGIN: after googleSignIn.signIn account=$account');
      if (account == null) {
        debugPrint('LOGIN: account is null (cancelled)');
        return;
      }

      final GoogleSignInAuthentication auth = await account.authentication;
      final String? idToken = auth.idToken;
      final String? accessToken = auth.accessToken;
      debugPrint('LOGIN: idToken is null? ${idToken==null}');
      debugPrint('LOGIN: accessToken is null? ${accessToken==null}');
      if (idToken == null || idToken.isEmpty) {
        return;
      }

      final Uri authUri = Uri.parse(_googleAuthUrl);
      debugPrint('LOGIN: backend url=$authUri');
      final response = await http.post(
        authUri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken}),
      ).timeout(const Duration(seconds: 12));
      final String bodySnippet = response.body.length > 200
          ? response.body.substring(0, 200)
          : response.body;
      debugPrint('LOGIN: backend statusCode=${response.statusCode}');
      debugPrint('LOGIN: backend bodySnippet=$bodySnippet');
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
    } on TimeoutException catch (e) {
      debugPrint('LOGIN: timeout while calling backend: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google giris zaman asimi')),
      );
    } on SocketException catch (e) {
      debugPrint('LOGIN: socket error during login flow: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ag baglanti hatasi')),
      );
    } on PlatformException catch (e) {
      debugPrint('LOGIN: platform exception during Google sign-in: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google giris hatasi')),
      );
    } catch (e, st) {
      debugPrint('LOGIN: unexpected error: $e');
      debugPrint('LOGIN: stacktrace: $st');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google giris hatasi')),
      );
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

class GoogleLoginScreen extends LoginScreen {
  GoogleLoginScreen({super.key});
}
