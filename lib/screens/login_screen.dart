import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/core/config.dart';
import 'package:pdf/core/token_service.dart';

import '../auth/auth_state.dart';
import '../auth/google_auth_service.dart' show kServerClientId;
import '../ui/home_screen.dart';

class LoginScreen extends StatelessWidget {
  LoginScreen({super.key});

  static const String _googleAuthUrl = '${AppConfig.baseUrl}/auth/google';

  void _logRequestDebug({
    required String method,
    required String fullUrl,
    required Map<String, String> headers,
  }) {
    final authHeader = headers['Authorization'] ?? '';
    final hasAuthHeader = authHeader.startsWith('Bearer ');
    final token = hasAuthHeader ? authHeader.substring(7).trim() : '';
    final tokenParts = token.isEmpty ? 0 : token.split('.').length;
    final tokenLen = token.length;
    debugPrint(
      'HTTPDBG fullUrl=$fullUrl method=$method hasAuthHeader=$hasAuthHeader tokenParts=$tokenParts tokenLen=$tokenLen',
    );
    if (tokenParts != 0 && tokenParts != 3) {
      debugPrint('HTTPDBG INVALID TOKEN FORMAT');
      throw Exception('INVALID TOKEN FORMAT');
    }
  }

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
      const authHeaders = <String, String>{'Content-Type': 'application/json'};
      _logRequestDebug(
        method: 'POST',
        fullUrl: _googleAuthUrl,
        headers: authHeaders,
      );
      final response = await http.post(
        authUri,
        headers: authHeaders,
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

      await TokenService.save(token);
      await saveToken(token);
      print('STEP4: tokenSaved=true');
      final Uri meUri = Uri.parse('${AppConfig.baseUrl}/me');
      print('STEP4: calling GET /me -> $meUri');
      final meHeaders = <String, String>{
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      };
      _logRequestDebug(
        method: 'GET',
        fullUrl: '${AppConfig.baseUrl}/me',
        headers: meHeaders,
      );
      final http.Response meResponse = await http.get(
        meUri,
        headers: meHeaders,
      );
      final String meBodySnippet = meResponse.body.length > 120
          ? meResponse.body.substring(0, 120)
          : meResponse.body;
      print('STEP4: /me status=${meResponse.statusCode}');
      print('STEP4: /me bodySnippet=$meBodySnippet');
      if (meResponse.statusCode != 200) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('STEP4 FAIL: /me returned ${meResponse.statusCode}')),
        );
        return;
      }
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
