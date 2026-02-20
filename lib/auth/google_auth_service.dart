import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kServerClientId = "558568249668-a5pud3bk0cet0b4kr6r3926avu7tiq80.apps.googleusercontent.com";

class GoogleAuthService {
  GoogleAuthService({GoogleSignIn? googleSignIn})
    : _googleSignIn =
          googleSignIn ??
          GoogleSignIn(
            scopes: const <String>['openid', 'email'],
            serverClientId: kServerClientId,
          );

  final GoogleSignIn _googleSignIn;

  Future<String?> signIn() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        return null;
      }

      final GoogleSignInAuthentication auth = await account.authentication;
      final String? idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        return null;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('id_token', idToken);

      return idToken;
    } catch (_) {
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('id_token');
  }
}
