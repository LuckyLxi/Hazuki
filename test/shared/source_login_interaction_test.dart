import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/source/account/source_login_interaction.dart';
import 'package:hazuki/shared/source_account/source_login_interaction_dialog.dart';
import 'package:hazuki/shared/source_account/source_account_dialogs.dart';

void main() {
  testWidgets(
    'cancelling embedded input closes the whole login while preserving the page',
    (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (c) {
              context = c;
              return const Scaffold(body: Text('Home'));
            },
          ),
        ),
      );
      final cancellation = SourceLoginCancellation();
      final dialog = showHomeLoginDialog(
        context,
        initialUsername: '',
        initialAvatarUrl: '',
        firstUseText: '',
        loginMethods: const [
          SourceLoginMethod(id: 'prompt', title: 'Prompt', input: 'none'),
        ],
        onLogin: (_, _) async => throw StateError('legacy'),
        onLoginMethod: (_, _, _, present) async {
          await present({
            'type': 'text',
            'title': 'Additional input',
          }, cancellation);
          return const HomeLoginDialogProfile(username: 'User', avatarUrl: '');
        },
        onDismissed: cancellation.cancel,
        onLogoutTap: () {},
        onRequestSaveAvatar: (_) async {},
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.text('Additional input'), findsOneWidget);
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      await dialog;
      expect(cancellation.isCancelled, isTrue);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Home'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('disposing a prompt cancels its outstanding host result', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (c) {
            context = c;
            return const Scaffold();
          },
        ),
      ),
    );
    final cancellation = SourceLoginCancellation();
    final pending = showSourceLoginInteraction(context, {
      'type': 'text',
      'title': 'Input',
    }, cancellation);
    final assertion = expectLater(
      pending,
      throwsA(isA<SourceLoginCancelled>()),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await assertion;
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'captcha returns ordered original pixels and refresh starts with no selected points',
    (tester) async {
      final bytes = (await tester.runAsync(
        () => File(
          'assets/images/downloaded_cover_placeholder.png',
        ).readAsBytes(),
      ))!;
      final original = await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final size = Size(
          frame.image.width.toDouble(),
          frame.image.height.toDouble(),
        );
        frame.image.dispose();
        codec.dispose();
        return size;
      });
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (c) {
              context = c;
              return const Scaffold();
            },
          ),
        ),
      );
      final request = <String, dynamic>{
        'type': 'clickCaptcha',
        'title': 'Click',
        'image': bytes,
        'pointCount': 2,
      };
      Future<void> decoded() async {
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 50));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
        }
      }

      final result = showSourceLoginInteraction(
        context,
        request,
        SourceLoginCancellation(),
      );
      await decoded();
      final rect = tester.getRect(
        find.byKey(const ValueKey('login-click-captcha')),
      );
      final first = rect.center + const Offset(18, 12),
          second = rect.center - const Offset(20, 18);
      await tester.tapAt(first);
      await tester.pump();
      await tester.tapAt(second);
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      final value = await result as Map;
      final p1 = captchaImagePoint(first - rect.topLeft, rect.size, original!)!;
      final p2 = captchaImagePoint(second - rect.topLeft, rect.size, original)!;
      expect(value['points'], [
        {'x': p1.dx.floor(), 'y': p1.dy.floor()},
        {'x': p2.dx.floor(), 'y': p2.dy.floor()},
      ]);
      final refresh = showSourceLoginInteraction(
        context,
        request,
        SourceLoginCancellation(),
      );
      await decoded();
      await tester.tapAt(
        tester
            .getRect(find.byKey(const ValueKey('login-click-captcha')))
            .center,
      );
      await tester.tap(find.text('Refresh captcha'));
      await tester.pumpAndSettle();
      expect(await refresh, {'status': 'refresh'});
      final token = SourceLoginCancellation();
      final next = showSourceLoginInteraction(context, request, token);
      final assertion = expectLater(next, throwsA(isA<SourceLoginCancelled>()));
      await decoded();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      token.cancel();
      await tester.pumpAndSettle();
      await assertion;
    },
  );

  testWidgets(
    'declared SMS method needs no password and closing parent cancels immediately',
    (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (c) {
              context = c;
              return const Scaffold();
            },
          ),
        ),
      );
      var cancelled = false;
      final profile = Completer<HomeLoginDialogProfile>();
      final calls = <String>[];
      final dialog = showHomeLoginDialog(
        context,
        initialUsername: '',
        initialAvatarUrl: '',
        firstUseText: '',
        loginMethods: const [
          SourceLoginMethod(id: 'sms', title: 'SMS', input: 'account'),
        ],
        onLogin: (_, _) async =>
            throw StateError('Legacy callback must not run'),
        onLoginMethod: (account, password, method, _) {
          calls.add('$account/$password/$method');
          return profile.future;
        },
        onDismissed: () => cancelled = true,
        onLogoutTap: () {},
        onRequestSaveAvatar: (_) async {},
      );
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), '12345');
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(calls, ['12345//sms']);
      await tester.binding.handlePopRoute();
      expect(cancelled, isTrue);
      await tester.pumpAndSettle();
      await dialog;
      profile.complete(
        const HomeLoginDialogProfile(username: 'Late', avatarUrl: ''),
      );
      await tester.pump();
      expect(find.text('Late'), findsNothing);
    },
  );
  test(
    'scaled coordinates ignore letterbox padding and preserve original pixels',
    () {
      const canvas = Size(300, 300), original = Size(600, 300);
      expect(
        captchaImagePoint(const Offset(60, 90), canvas, original),
        const Offset(120, 30),
      );
      expect(
        captchaImagePoint(const Offset(150, 60), canvas, original),
        isNull,
      );
      expect(
        captchaImagePoint(const Offset(300, 150), canvas, original),
        isNull,
      );
      expect(captchaImagePoint(Offset.zero, Size.zero, original), isNull);
    },
  );

  testWidgets(
    'text prompts return input and cancellation ends pending prompt',
    (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (c) {
              context = c;
              return const Scaffold();
            },
          ),
        ),
      );
      final token = SourceLoginCancellation();
      final result = showSourceLoginInteraction(context, {
        'type': 'text',
        'title': 'SMS',
      }, token);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '123456');
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(await result, '123456');
      final cancelled = SourceLoginCancellation();
      final pending = showSourceLoginInteraction(context, {
        'type': 'text',
        'title': 'Again',
      }, cancelled);
      final assertion = expectLater(
        pending,
        throwsA(isA<SourceLoginCancelled>()),
      );
      await tester.pumpAndSettle();
      cancelled.cancel();
      await tester.pumpAndSettle();
      await assertion;
      expect(find.byType(TextField), findsNothing);
    },
  );
}
