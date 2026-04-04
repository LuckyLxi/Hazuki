import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PasswordVerificationResult { incomplete, success, failed, lockedOut }

class PasswordLockService extends ChangeNotifier {
  PasswordLockService._();

  static final PasswordLockService instance = PasswordLockService._();
  static const MethodChannel _privacyChannel = MethodChannel(
    'hazuki.comics/privacy',
  );

  static const int maxAttempts = 3;
  static const Duration lockoutDuration = Duration(minutes: 5);
  static const String _enabledKey = 'password_lock_enabled';
  static const String _hashKey = 'password_lock_hash';
  static const String _failedAttemptsKey = 'password_lock_failed_attempts';
  static const String _lockoutUntilKey = 'password_lock_lockout_until_ms';

  bool _initialized = false;
  bool _enabled = false;
  bool _sessionUnlocked = true;
  bool _biometricEnabled = false;
  bool _authOnResume = false;
  bool _authenticatingBiometric = false;
  bool _ignoreNextResumeAuthCheck = false;
  int _failedAttempts = 0;
  String _input = '';
  DateTime? _lockoutUntil;
  Timer? _lockoutTimer;
  bool _wasInBackground = false;

  bool get isInitialized => _initialized;
  bool get isEnabled => _enabled;
  bool get isSessionUnlocked => _sessionUnlocked;
  bool get shouldBlockApp => _initialized && _enabled && !_sessionUnlocked;
  bool get biometricEnabled => _biometricEnabled;
  bool get authOnResume => _authOnResume;
  bool get authenticatingBiometric => _authenticatingBiometric;
  String get input => _input;
  int get failedAttempts => _failedAttempts;

  DateTime? get lockoutUntil => _lockoutUntil;
  bool get isLockedOut {
    final until = _lockoutUntil;
    return until != null && until.isAfter(DateTime.now());
  }

  Duration get lockoutRemaining {
    final until = _lockoutUntil;
    if (until == null) {
      return Duration.zero;
    }
    final remaining = until.difference(DateTime.now());
    if (remaining.isNegative) {
      return Duration.zero;
    }
    return remaining;
  }

  int get remainingAttempts {
    if (isLockedOut) {
      return 0;
    }
    return maxAttempts - _failedAttempts;
  }

  bool get showBiometricButton => _biometricEnabled && !isLockedOut;

  Future<void> ensureInitialized() async {
    if (_initialized) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_enabledKey) ?? false;
    _failedAttempts = prefs.getInt(_failedAttemptsKey) ?? 0;
    final lockoutUntilMs = prefs.getInt(_lockoutUntilKey);
    _lockoutUntil = lockoutUntilMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(lockoutUntilMs);
    await _clearExpiredLockoutIfNeeded(prefs);
    await refreshPrivacySettings();
    _sessionUnlocked = !_enabled;
    _initialized = true;
    _restartLockoutTicker();
    notifyListeners();
  }

  Future<void> refreshPrivacySettings() async {
    try {
      final dynamic result = await _privacyChannel.invokeMethod(
        'getPrivacySettings',
      );
      if (result is Map) {
        _biometricEnabled = result['biometricAuth'] == true;
        _authOnResume = result['authOnResume'] == true;
      }
    } catch (_) {}
  }

  Future<void> enableWithPin(String pin) async {
    final normalized = pin.trim();
    if (normalized.length != 4) {
      throw Exception('password_lock_pin_invalid');
    }
    final prefs = await SharedPreferences.getInstance();
    final hash = _hashPin(normalized);
    await prefs.setBool(_enabledKey, true);
    await prefs.setString(_hashKey, hash);
    await prefs.setInt(_failedAttemptsKey, 0);
    await prefs.remove(_lockoutUntilKey);
    _enabled = true;
    _sessionUnlocked = true;
    _failedAttempts = 0;
    _input = '';
    _lockoutUntil = null;
    await _syncNativePasswordLockState(true);
    _restartLockoutTicker();
    notifyListeners();
  }

  Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_enabledKey);
    await prefs.remove(_hashKey);
    await prefs.remove(_failedAttemptsKey);
    await prefs.remove(_lockoutUntilKey);
    _enabled = false;
    _sessionUnlocked = true;
    _failedAttempts = 0;
    _input = '';
    _lockoutUntil = null;
    _authenticatingBiometric = false;
    await _syncNativePasswordLockState(false);
    _restartLockoutTicker();
    notifyListeners();
  }

  void relock() {
    if (!_enabled) {
      return;
    }
    _sessionUnlocked = false;
    _input = '';
    notifyListeners();
  }

  void clearInput() {
    if (_input.isEmpty) {
      return;
    }
    _input = '';
    notifyListeners();
  }

  void removeLastDigit() {
    if (_input.isEmpty || isLockedOut) {
      return;
    }
    _input = _input.substring(0, _input.length - 1);
    notifyListeners();
  }

  Future<PasswordVerificationResult> appendDigit(String digit) async {
    if (!_enabled || isLockedOut) {
      return isLockedOut
          ? PasswordVerificationResult.lockedOut
          : PasswordVerificationResult.incomplete;
    }
    if (digit.length != 1 ||
        digit.codeUnitAt(0) < 48 ||
        digit.codeUnitAt(0) > 57) {
      return PasswordVerificationResult.incomplete;
    }
    if (_input.length >= 4) {
      return PasswordVerificationResult.incomplete;
    }
    _input = '$_input$digit';
    notifyListeners();
    if (_input.length < 4) {
      return PasswordVerificationResult.incomplete;
    }
    return _verifyCurrentInput();
  }

  Future<bool> authenticateWithBiometric() async {
    if (!_enabled || !_biometricEnabled || _authenticatingBiometric) {
      return false;
    }
    _authenticatingBiometric = true;
    _ignoreNextResumeAuthCheck = false;
    notifyListeners();
    try {
      final success = await _privacyChannel.invokeMethod<bool>('authenticate');
      if (success == true) {
        await _markUnlocked();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    } finally {
      _authenticatingBiometric = false;
      notifyListeners();
    }
  }

  Future<void> handleAppLifecycleState(AppLifecycleState state) async {
    if (!_enabled) {
      if (state == AppLifecycleState.resumed) {
        _wasInBackground = false;
      } else if (state == AppLifecycleState.hidden ||
          state == AppLifecycleState.paused) {
        _wasInBackground = true;
      }
      return;
    }

    if (state == AppLifecycleState.resumed) {
      if (_ignoreNextResumeAuthCheck) {
        _ignoreNextResumeAuthCheck = false;
        _wasInBackground = false;
        return;
      }
      if (_wasInBackground && _authOnResume) {
        relock();
      }
      _wasInBackground = false;
      return;
    }

    if (_authenticatingBiometric &&
        (state == AppLifecycleState.inactive ||
            state == AppLifecycleState.hidden ||
            state == AppLifecycleState.paused)) {
      // System biometric dialogs can transiently change lifecycle state.
      _ignoreNextResumeAuthCheck = true;
      return;
    }

    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _wasInBackground = true;
    }
  }

  Future<PasswordVerificationResult> _verifyCurrentInput() async {
    final prefs = await SharedPreferences.getInstance();
    final expectedHash = prefs.getString(_hashKey) ?? '';
    final inputHash = _hashPin(_input);
    if (inputHash == expectedHash && expectedHash.isNotEmpty) {
      await _markUnlocked();
      return PasswordVerificationResult.success;
    }

    _failedAttempts += 1;
    _input = '';
    if (_failedAttempts >= maxAttempts) {
      _failedAttempts = 0;
      _lockoutUntil = DateTime.now().add(lockoutDuration);
      await prefs.setInt(
        _lockoutUntilKey,
        _lockoutUntil!.millisecondsSinceEpoch,
      );
      await prefs.setInt(_failedAttemptsKey, _failedAttempts);
      _restartLockoutTicker();
      notifyListeners();
      return PasswordVerificationResult.lockedOut;
    }

    await prefs.setInt(_failedAttemptsKey, _failedAttempts);
    notifyListeners();
    return PasswordVerificationResult.failed;
  }

  Future<void> _markUnlocked() async {
    final prefs = await SharedPreferences.getInstance();
    _sessionUnlocked = true;
    _failedAttempts = 0;
    _input = '';
    _lockoutUntil = null;
    await prefs.setInt(_failedAttemptsKey, 0);
    await prefs.remove(_lockoutUntilKey);
    _restartLockoutTicker();
    notifyListeners();
  }

  Future<void> _clearExpiredLockoutIfNeeded(SharedPreferences prefs) async {
    if (_lockoutUntil == null) {
      return;
    }
    if (_lockoutUntil!.isAfter(DateTime.now())) {
      return;
    }
    _lockoutUntil = null;
    _failedAttempts = 0;
    await prefs.remove(_lockoutUntilKey);
    await prefs.setInt(_failedAttemptsKey, 0);
  }

  void _restartLockoutTicker() {
    _lockoutTimer?.cancel();
    if (!isLockedOut) {
      return;
    }
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (isLockedOut) {
        notifyListeners();
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      await _clearExpiredLockoutIfNeeded(prefs);
      _lockoutTimer?.cancel();
      notifyListeners();
    });
  }

  Future<void> _syncNativePasswordLockState(bool enabled) async {
    try {
      await _privacyChannel.invokeMethod('setPasswordLockEnabled', {
        'enabled': enabled,
      });
    } catch (_) {}
  }

  String _hashPin(String pin) {
    return sha256.convert(utf8.encode(pin)).toString();
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    super.dispose();
  }
}
