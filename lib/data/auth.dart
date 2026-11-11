import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/format.dart';
import 'models.dart';

/// Where a one-time code goes. There is no SMS gateway yet, so [DemoOtpSender]
/// hands the code to the screen. When a backend exists, write an `OtpSender`
/// that calls it and pass that to [AuthController] — nothing else changes.
abstract class OtpSender {
  Future<void> send(String phone, String code);
}

class DemoOtpSender implements OtpSender {
  @override
  Future<void> send(String phone, String code) async {
    // Intentionally nothing to send: the code is displayed in the app.
  }
}

class OtpChallenge {
  final String phone;
  final String code;
  final DateTime expiresAt;
  final DateTime resendAt;
  int attempts = 0;

  OtpChallenge(this.phone, this.code, this.expiresAt, this.resendAt);

  bool get expired => DateTime.now().isAfter(expiresAt);
}

enum AuthStage { loading, signedOut, signedIn }

class AuthController extends ChangeNotifier {
  AuthController(this._prefs, {OtpSender? sender})
    : _sender = sender ?? DemoOtpSender();

  static const otpLifetime = Duration(minutes: 5);
  static const resendCooldown = Duration(seconds: 30);
  static const maxAttempts = 5;
  static const _accountsKey = 'accounts';
  static const _sessionKey = 'session_phone';

  final SharedPreferences _prefs;
  final OtpSender _sender;
  final _rand = Random.secure();

  final Map<String, SellerAccount> _accounts = {};
  OtpChallenge? challenge;
  String? _verifiedNewPhone; // passed OTP but still needs a profile

  AuthStage stage = AuthStage.loading;
  SellerAccount? current;

  /// True when the OTP service is the on-screen demo one.
  bool get isDemoOtp => _sender is DemoOtpSender;

  static Future<AuthController> create({OtpSender? sender}) async {
    final prefs = await SharedPreferences.getInstance();
    final c = AuthController(prefs, sender: sender);
    c._restore();
    return c;
  }

  SharedPreferences get prefs => _prefs;

  void _restore() {
    final raw = _prefs.getString(_accountsKey);
    if (raw != null) {
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        for (final e in m.entries) {
          _accounts[e.key] = SellerAccount.fromJson(
            Map<String, dynamic>.from(e.value as Map),
          );
        }
      } catch (_) {}
    }
    final session = _prefs.getString(_sessionKey);
    if (session != null && _accounts.containsKey(session)) {
      current = _accounts[session];
      stage = AuthStage.signedIn;
    } else {
      stage = AuthStage.signedOut;
    }
  }

  Future<void> _saveAccounts() => _prefs.setString(
    _accountsKey,
    jsonEncode(_accounts.map((k, v) => MapEntry(k, v.toJson()))),
  );

  bool accountExists(String phone) => _accounts.containsKey(phone);

  // ----------------------------------------------------------------- OTP

  /// Issues a new code. Returns an error message, or null on success.
  Future<String?> requestOtp(String rawPhone) async {
    final phone = normalizePhone(rawPhone);
    if (phone == null) {
      return 'Enter a valid mobile number, like 0917 123 4567.';
    }
    final existing = challenge;
    if (existing != null &&
        existing.phone == phone &&
        DateTime.now().isBefore(existing.resendAt)) {
      final secs = existing.resendAt.difference(DateTime.now()).inSeconds + 1;
      return 'Please wait $secs seconds before asking for a new code.';
    }
    final code = (100000 + _rand.nextInt(900000)).toString();
    final now = DateTime.now();
    challenge = OtpChallenge(
      phone,
      code,
      now.add(otpLifetime),
      now.add(resendCooldown),
    );
    _verifiedNewPhone = null;
    await _sender.send(phone, code);
    notifyListeners();
    return null;
  }

  /// Returns an error message, or null when the code is correct.
  /// After success, check [needsProfile]; otherwise the seller is signed in.
  Future<String?> verifyOtp(String code) async {
    final c = challenge;
    if (c == null) return 'Request a code first.';
    if (c.expired) {
      challenge = null;
      notifyListeners();
      return 'That code has expired. Request a new one.';
    }
    if (c.attempts >= maxAttempts) {
      challenge = null;
      notifyListeners();
      return 'Too many wrong tries. Request a new code.';
    }
    if (code.trim() != c.code) {
      c.attempts++;
      final left = maxAttempts - c.attempts;
      if (left <= 0) {
        challenge = null;
        notifyListeners();
        return 'Too many wrong tries. Request a new code.';
      }
      notifyListeners();
      return 'Wrong code. $left ${left == 1 ? 'try' : 'tries'} left.';
    }
    final phone = c.phone;
    challenge = null;
    if (_accounts.containsKey(phone)) {
      await _signIn(_accounts[phone]!);
    } else {
      _verifiedNewPhone = phone;
      notifyListeners();
    }
    return null;
  }

  bool get needsProfile => _verifiedNewPhone != null;
  String? get pendingPhone => _verifiedNewPhone;

  Future<void> completeProfile({
    required String ownerName,
    required String storeName,
  }) async {
    final phone = _verifiedNewPhone;
    if (phone == null) return;
    final account = SellerAccount(
      phone: phone,
      ownerName: ownerName.trim(),
      storeName: storeName.trim(),
    );
    _accounts[phone] = account;
    await _saveAccounts();
    _verifiedNewPhone = null;
    await _signIn(account);
  }

  Future<void> _signIn(SellerAccount a) async {
    current = a;
    stage = AuthStage.signedIn;
    await _prefs.setString(_sessionKey, a.phone);
    notifyListeners();
  }

  /// Ends the session. The seller's data stays on the phone for next sign-in.
  Future<void> signOut() async {
    current = null;
    challenge = null;
    _verifiedNewPhone = null;
    stage = AuthStage.signedOut;
    await _prefs.remove(_sessionKey);
    notifyListeners();
  }

  /// Back out of the OTP / profile step to change the phone number.
  void cancelChallenge() {
    challenge = null;
    _verifiedNewPhone = null;
    notifyListeners();
  }

  /// Call after profile edits so the saved account list stays current.
  Future<void> persistAccount() async {
    await _saveAccounts();
    notifyListeners();
  }

  /// Permanently removes this account and its data from the phone.
  Future<void> deleteAccount() async {
    final a = current;
    if (a == null) return;
    _accounts.remove(a.phone);
    await _saveAccounts();
    await _prefs.remove('data_${a.phone}');
    await signOut();
  }
}
