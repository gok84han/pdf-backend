import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenService {
  static const _kToken = 'auth_token';
  static const _storage = FlutterSecureStorage();

  static Future<void> save(String token) async {
    await _storage.write(key: _kToken, value: token);
  }

  static Future<String?> read() async {
    return _storage.read(key: _kToken);
  }

  static Future<void> clear() async {
    await _storage.delete(key: _kToken);
  }
}
