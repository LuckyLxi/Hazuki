import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/settings/view/security/password_lock_pages.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/password_lock_service.dart';

void main() {
  testWidgets('returning from passcode setup returns to privacy settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: _PrivacySettingsPage(service: PasswordLockService()),
      ),
    );

    await tester.tap(find.text('Password lock'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Enable password lock'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(PasswordLockSetupPage), findsOneWidget);
    expect(
      tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
      isTrue,
    );

    await tester.tap(find.byTooltip('Back').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(
      tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
      isFalse,
    );
  });
}

class _PrivacySettingsPage extends StatelessWidget {
  const _PrivacySettingsPage({required this.service});

  final PasswordLockService service;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () {
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => PasswordLockIntroPage(service: service),
              ),
            );
          },
          child: const Text('Password lock'),
        ),
      ),
    );
  }
}
