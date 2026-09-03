import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 로그인 편의: 이메일 기억 + 생체 잠금 설정. + local_auth 생체 인증 래퍼.
class LocalAuthPrefs {
  static const _kEmail = 'remember_email';
  static const _kBio = 'biometric_enabled';

  static String? rememberedEmail;
  static bool biometricEnabled = false;

  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    rememberedEmail = p.getString(_kEmail);
    biometricEnabled = p.getBool(_kBio) ?? false;
  }

  static Future<void> setRememberedEmail(String? email) async {
    rememberedEmail = email;
    final p = await SharedPreferences.getInstance();
    if (email == null || email.isEmpty) {
      await p.remove(_kEmail);
    } else {
      await p.setString(_kEmail, email);
    }
  }

  static Future<void> setBiometricEnabled(bool on) async {
    biometricEnabled = on;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kBio, on);
  }

  /// 기기가 생체 인증을 지원하고 등록돼 있는지.
  static Future<bool> canUseBiometric() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      if (!await _auth.canCheckBiometrics) return false;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// 생체 인증 실행. 성공 true.
  static Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
