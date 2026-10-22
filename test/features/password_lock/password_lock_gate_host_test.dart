import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/password_lock/view/password_lock_widgets.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/password_lock_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const MethodChannel _privacyChannel = MethodChannel('hazuki.comics/privacy');

void main() {
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
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_privacyChannel, null);
  });

  testWidgets('解锁后遮罩保留到揭开动画结束，且过程中不重建锁动画', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = PasswordLockService();
    await service.ensureInitialized();
    await service.enableWithPin('1234');
    service.relock();
    expect(service.shouldBlockApp, isTrue);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Stack(
          children: [
            const Scaffold(body: SizedBox.expand()),
            PasswordLockGateHost(controller: service),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1200));

    final headerState = tester.state(find.byType(LockGateAnimationHeader));
    final overlayState = tester.state(find.byType(PasswordLockGateOverlay));
    final clipElement = tester.element(
      find.descendant(
        of: find.byType(PasswordLockGateHost),
        matching: find.byType(ClipPath),
      ),
    );

    for (final digit in ['1', '2', '3', '4']) {
      await service.appendDigit(digit);
    }
    expect(service.shouldBlockApp, isFalse);

    // 解锁动画保留阶段：遮罩仍在
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(PasswordLockGateOverlay), findsOneWidget);

    // 进入揭开阶段后，遮罩子树与裁剪层都必须沿用原有实例，否则会闪一下
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      tester.state(find.byType(LockGateAnimationHeader)),
      same(headerState),
    );
    expect(
      tester.state(find.byType(PasswordLockGateOverlay)),
      same(overlayState),
    );
    expect(
      tester.element(
        find.descendant(
          of: find.byType(PasswordLockGateHost),
          matching: find.byType(ClipPath),
        ),
      ),
      same(clipElement),
    );

    // 揭开结束后遮罩移除
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.byType(PasswordLockGateOverlay), findsNothing);
  });

  testWidgets('服务已解除阻挡但尚未通知时重建，遮罩不能消失', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _ManualPasswordLockService();
    Widget buildApp(int generation) => MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Stack(
        children: [
          Scaffold(body: Text('page $generation')),
          PasswordLockGateHost(controller: service),
        ],
      ),
    );

    await tester.pumpWidget(buildApp(0));
    await tester.pump(const Duration(milliseconds: 1200));
    final overlayState = tester.state(find.byType(PasswordLockGateOverlay));

    // 模拟 _markUnlocked 在写入偏好期间：状态已变，但 notifyListeners 尚未发出，
    // 此时恰有一帧因其他原因重建
    service.blocking = false;
    await tester.pumpWidget(buildApp(1));
    expect(find.byType(PasswordLockGateOverlay), findsOneWidget);
    expect(
      tester.state(find.byType(PasswordLockGateOverlay)),
      same(overlayState),
    );

    service.notify();
    await tester.pump();
    expect(
      tester.state(find.byType(PasswordLockGateOverlay)),
      same(overlayState),
    );

    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(PasswordLockGateOverlay), findsNothing);
  });
}

/// 可手动控制阻挡状态与通知时机的服务替身。
class _ManualPasswordLockService extends PasswordLockService {
  bool blocking = true;

  @override
  bool get shouldBlockApp => blocking;

  void notify() => notifyListeners();
}
