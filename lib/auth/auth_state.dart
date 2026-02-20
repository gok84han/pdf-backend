import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/login_screen.dart';
import '../ui/home_screen.dart';

const String _kIdTokenKey = 'id_token';

Future<void> saveToken(String idToken) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kIdTokenKey, idToken);
}

Future<void> saveDevTokenForTesting(String token) {
  if (!kDebugMode) {
    throw UnsupportedError('saveDevTokenForTesting is debug-only.');
  }
  return saveToken(token);
}

Future<String?> loadToken() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getString(_kIdTokenKey);
}

Future<void> clearToken() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('id_token');
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Future<String?> _tokenFuture;
  bool _didNavigate = false;

  @override
  void initState() {
    super.initState();
    _tokenFuture = loadToken();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _tokenFuture,
      builder: (BuildContext context, AsyncSnapshot<String?> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          debugPrint('AuthGate token check error: ${snapshot.error}');
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final String? token = snapshot.data;
        if (!_didNavigate) {
          _didNavigate = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (token != null && token.isNotEmpty) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const HomeScreen(),
                ),
              );
            } else {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => LoginScreen(),
                ),
              );
            }
          });
        }

        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}
