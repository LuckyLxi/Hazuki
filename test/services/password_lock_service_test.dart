import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/password_lock_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const MethodChannel _privacyChannel = MethodChannel('hazuki.comics/privacy');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_privacyChannel, (call) async {
          if (call.method == 'getPrivacySettings') {
            return <String, dynamic>{
              'biometricAuth': false,
              'authOnResume': false,
            };
          }
          if (call.method == 'authenticate') {
            return false;
          }
          // setPasswordLockEnabled — no-op
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_privacyChannel, null);
  });

  group('PasswordLockService.ensureInitialized', () {
    test('starts disabled with unlocked session on a fresh install', () async {
      final service = PasswordLockService();
      await service.ensureInitialized();
      expect(service.isInitialized, isTrue);
      expect(service.isEnabled, isFalse);
      expect(service.isSessionUnlocked, isTrue);
      expect(service.shouldBlockApp, isFalse);
    });

    test('restores enabled state from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'password_lock_enabled': true,
        'password_lock_hash': 'irrelevant-hash',
        'password_lock_failed_attempts': 0,
      });
      final service = PasswordLockService();
      await service.ensureInitialized();
      expect(service.isEnabled, isTrue);
      expect(service.isSessionUnlocked, isFalse);
      expect(service.shouldBlockApp, isTrue);
    });
  });

  group('PasswordLockService.enableWithPin', () {
    test('rejects pins that are not exactly 4 digits', () async {
      final service = PasswordLockService();
      await service.ensureInitialized();
      expect(() => service.enableWithPin('123'), throwsException);
      expect(() => service.enableWithPin('12345'), throwsException);
    });

    test('enables the lock and starts in unlocked session', () async {
      final service = PasswordLockService();
      await service.ensureInitialized();
      await service.enableWithPin('1234');
      expect(service.isEnabled, isTrue);
      expect(service.isSessionUnlocked, isTrue);
      expect(service.shouldBlockApp, isFalse);
    });
  });

  group('PasswordLockService input flow', () {
    late PasswordLockService service;

    setUp(() async {
      service = PasswordLockService();
      await service.ensureInitialized();
      await service.enableWithPin('1234');
      service.relock();
    });

    test('relock locks the current session', () {
      expect(service.shouldBlockApp, isTrue);
      expect(service.input, '');
    });

    test('appendDigit accepts the correct pin and unlocks', () async {
      expect(
        await service.appendDigit('1'),
        PasswordVerificationResult.incomplete,
      );
      expect(
        await service.appendDigit('2'),
        PasswordVerificationResult.incomplete,
      );
      expect(
        await service.appendDigit('3'),
        PasswordVerificationResult.incomplete,
      );
      expect(
        await service.appendDigit('4'),
        PasswordVerificationResult.success,
      );
      expect(service.isSessionUnlocked, isTrue);
    });

    test('appendDigit ignores non-digit characters', () async {
      expect(
        await service.appendDigit('a'),
        PasswordVerificationResult.incomplete,
      );
      expect(service.input, '');
    });

    test(
      'wrong pin increments failed attempts; 3 failures trigger lockout',
      () async {
        Future<PasswordVerificationResult> enter(String pin) async {
          PasswordVerificationResult last =
              PasswordVerificationResult.incomplete;
          for (final c in pin.split('')) {
            last = await service.appendDigit(c);
          }
          return last;
        }

        expect(await enter('9999'), PasswordVerificationResult.failed);
        expect(service.remainingAttempts, 2);
        expect(await enter('9999'), PasswordVerificationResult.failed);
        expect(service.remainingAttempts, 1);
        expect(await enter('9999'), PasswordVerificationResult.lockedOut);
        expect(service.isLockedOut, isTrue);
        expect(service.remainingAttempts, 0);
      },
    );

    test(
      'removeLastDigit pops one character and clearInput empties input',
      () async {
        await service.appendDigit('1');
        await service.appendDigit('2');
        service.removeLastDigit();
        expect(service.input, '1');
        service.clearInput();
        expect(service.input, '');
      },
    );
  });

  group('PasswordLockService.disable', () {
    test('clears enabled state and unblocks the app', () async {
      final service = PasswordLockService();
      await service.ensureInitialized();
      await service.enableWithPin('1234');
      service.relock();
      expect(service.shouldBlockApp, isTrue);

      await service.disable();
      expect(service.isEnabled, isFalse);
      expect(service.shouldBlockApp, isFalse);
      expect(service.isSessionUnlocked, isTrue);
    });
  });
}
