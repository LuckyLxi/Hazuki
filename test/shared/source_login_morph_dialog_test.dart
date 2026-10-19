import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/source/account/source_browser_authorization.dart';
import 'package:hazuki/services/source/account/source_external_authorization.dart';
import 'package:hazuki/services/source/account/source_login_interaction.dart';
import 'package:hazuki/services/source/gateways/source_image_gateways.dart';
import 'package:hazuki/shared/source_account/source_account_dialogs.dart';
import 'package:hazuki/shared/source_account/source_authorization_browser.dart';
import 'package:hazuki/shared/source_account/source_browser_authorization_dialog.dart';
import 'package:hazuki/shared/source_account/source_login_dialog_controller.dart';
import 'package:hazuki/widgets/source_image_gateway_scope.dart';

void main() {
  for (final locale in const [Locale('zh'), Locale('en')]) {
    for (final width in [320.0, 390.0]) {
      testWidgets(
        'captcha actions stay in one row before and after selecting points ($locale, $width)',
        (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final image = (await tester.runAsync(
            () => File(
              'assets/images/downloaded_cover_placeholder.png',
            ).readAsBytes(),
          ))!;
          final host = await _mount(tester, locale: locale);
          final token = SourceLoginCancellation();
          final dialog = _open(host.context, token, (present) async {
            await present({
              'type': 'clickCaptcha',
              'image': image,
              'pointCount': 1,
            }, token);
          });
          await tester.pumpAndSettle();
          await tester.tap(find.byType(FilledButton));
          for (var frame = 0; frame < 12; frame++) {
            await tester.pump(const Duration(milliseconds: 50));
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)),
            );
          }
          final footer = find.byKey(const ValueKey('login-captcha-actions'));
          final undo = find.descendant(
            of: footer,
            matching: find.byType(IconButton),
          );
          final confirm = find.descendant(
            of: footer,
            matching: find.byType(FilledButton),
          );
          final initialBounds = tester.getRect(footer);
          final actionBounds = <Rect>[
            for (final element
                in find
                    .descendant(
                      of: footer,
                      matching: find.byWidgetPredicate(
                        (widget) =>
                            widget is TextButton ||
                            widget is IconButton ||
                            widget is FilledButton,
                      ),
                    )
                    .evaluate())
              tester.getRect(find.byWidget(element.widget)),
          ];
          expect(actionBounds, hasLength(4));
          for (var i = 0; i < actionBounds.length; i++) {
            expect(
              actionBounds[i].center.dy,
              closeTo(initialBounds.center.dy, 0.01),
            );
            if (i > 0) {
              expect(
                actionBounds[i].left,
                greaterThanOrEqualTo(actionBounds[i - 1].right),
              );
            }
          }
          expect(tester.widget<IconButton>(undo).onPressed, isNull);
          expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
          await tester.tap(find.byKey(const ValueKey('login-click-captcha')));
          await tester.pumpAndSettle();
          expect(tester.getRect(footer), initialBounds);
          expect(tester.widget<IconButton>(undo).onPressed, isNotNull);
          expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
          await tester.tap(undo);
          await tester.pumpAndSettle();
          expect(tester.getRect(footer), initialBounds);
          expect(tester.widget<IconButton>(undo).onPressed, isNull);
          expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
          expect(tester.takeException(), isNull);
          token.cancel();
          await tester.pumpAndSettle();
          await dialog;
        },
      );
    }
  }

  testWidgets(
    'phone captcha keeps morphing when its image decodes next frame',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.reset);
      final image = (await tester.runAsync(
        () => File(
          'assets/images/downloaded_cover_placeholder.png',
        ).readAsBytes(),
      ))!;
      final host = await _mount(tester);
      final token = SourceLoginCancellation();
      final response = Completer<void>();
      final controller = SourceLoginDialogController();
      addTearDown(controller.dispose);
      final dialog = _open(
        host.context,
        token,
        (present) async {
          await response.future;
          await present({
            'type': 'clickCaptcha',
            'title': 'Phone login verification',
            'message': 'Click the characters in order',
            'image': image,
            'hintImage': image,
            'pointCount': 1,
          }, token);
        },
        controller: controller,
        input: 'account',
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '13800000000');
      await tester.tap(find.byType(FilledButton));
      tester.view.resetViewInsets();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final loadingSize = tester.getSize(find.byType(AnimatedSize));
      response.complete();
      await tester.pump();
      final firstSize = tester.getSize(find.byType(AnimatedSize));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      final decodedSize = tester.getSize(find.byType(AnimatedSize));
      await tester.pump(const Duration(milliseconds: 80));
      final middleSize = tester.getSize(find.byType(AnimatedSize));
      final fade = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.byWidget(controller.value!),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, greaterThan(0));
      expect(fade.opacity.value, lessThan(1));
      final imageFade = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('captcha-image-ready')),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(imageFade.opacity.value, greaterThan(0));
      expect(imageFade.opacity.value, lessThan(1));
      await tester.pumpAndSettle();
      final finalSize = tester.getSize(find.byType(AnimatedSize));
      expect(firstSize.height, closeTo(loadingSize.height, 0.01));
      expect(decodedSize.height, closeTo(firstSize.height, 0.01));
      expect(middleSize.height, greaterThan(decodedSize.height));
      expect(middleSize.height, lessThan(finalSize.height));
      expect(host.observer.pushes, 2);
      token.cancel();
      await tester.pumpAndSettle();
      await dialog;
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('captcha refresh creates fresh points in the same dialog', (
    tester,
  ) async {
    final image = (await tester.runAsync(
      () =>
          File('assets/images/downloaded_cover_placeholder.png').readAsBytes(),
    ))!;
    final host = await _mount(tester);
    final token = SourceLoginCancellation();
    final answers = <Object?>[];
    final dialog = _open(host.context, token, (present) async {
      for (var i = 0; i < 2; i++) {
        answers.add(
          await present({
            'type': 'clickCaptcha',
            'title': 'Captcha',
            'image': image,
            'pointCount': 1,
          }, token),
        );
      }
    });
    await tester.pumpAndSettle();
    final surface = tester.element(find.byType(Dialog));
    await tester.tap(find.byType(FilledButton));
    for (var i = 0; i < 2; i++) {
      for (var frame = 0; frame < 12; frame++) {
        await tester.pump(const Duration(milliseconds: 50));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
      }
      expect(tester.element(find.byType(Dialog)), same(surface));
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('login-click-captcha')));
      await tester.pumpAndSettle();
      if (i == 0) {
        await tester.tap(find.text('Refresh captcha'));
      } else {
        await tester.tap(find.byType(FilledButton));
      }
    }
    await tester.pumpAndSettle();
    expect(answers.first, {'status': 'refresh'});
    expect((answers.last as Map)['status'], 'submitted');
    expect(find.text('User'), findsOneWidget);
    expect(host.observer.pushes, 2);
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    await dialog;
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'closing during browser preparation cancels and releases late resources',
    (tester) async {
      final host = await _mount(tester);
      final token = SourceLoginCancellation();
      final browser = _Browser();
      final controller = SourceLoginDialogController();
      addTearDown(controller.dispose);
      final dialog = _open(host.context, token, (_) async {
        await showSourceBrowserAuthorization(
          host.context,
          {'url': 'https://site.example/login', 'completion': 'manual'},
          token,
          browserFactory: () => browser,
          dialogController: controller,
        );
      }, controller: controller);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      await tester.binding.handlePopRoute();
      expect(token.isCancelled, isTrue);
      await tester.pumpAndSettle();
      await dialog;
      browser.ready.complete();
      await tester.pumpAndSettle();
      expect(browser.closed, isTrue);
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Home'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('input steps and profile share one route and dialog surface', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);
    final host = await _mount(tester);
    final token = SourceLoginCancellation();
    final answers = <Object?>[];
    final dialog = _open(host.context, token, (present) async {
      for (var i = 0; i < 2; i++) {
        answers.add(await present({'type': 'text', 'title': 'Code $i'}, token));
      }
    });
    await tester.pumpAndSettle();
    final surface = tester.element(find.byType(Dialog));
    final backdrop = tester.element(find.byType(BackdropFilter));
    await tester.tap(find.byType(FilledButton));
    for (var i = 0; i < 2; i++) {
      await tester.pumpAndSettle();
      expect(find.text('Code $i'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(tester.element(find.byType(Dialog)), same(surface));
      expect(tester.element(find.byType(BackdropFilter)), same(backdrop));
      expect(host.observer.pushes, 2); // Home and the original login dialog.
      await tester.enterText(find.byType(TextField), 'answer-$i');
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
    }
    await tester.pumpAndSettle();
    expect(answers, ['answer-0', 'answer-1']);
    expect(find.text('User'), findsOneWidget);
    expect(tester.element(find.byType(Dialog)), same(surface));
    expect(host.observer.pushes, 2);
    expect(token.isCancelled, isFalse);
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    await dialog;
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed step returns to the form and can be retried', (
    tester,
  ) async {
    final host = await _mount(tester);
    final token = SourceLoginCancellation();
    var attempts = 0;
    final dialog = _open(host.context, token, (present) async {
      attempts++;
      await present({'type': 'text', 'title': 'Code'}, token);
      if (attempts == 1) throw StateError('Rejected code');
    });
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '1234');
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(host.observer.pushes, 2);
      if (i == 0) expect(find.textContaining('Rejected code'), findsOneWidget);
    }
    expect(find.text('User'), findsOneWidget);
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    await dialog;
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'browser step expands the same dialog and cleans up before profile',
    (tester) async {
      final host = await _mount(tester);
      final token = SourceLoginCancellation();
      final browser = _Browser()..ready.complete();
      final controller = SourceLoginDialogController();
      addTearDown(controller.dispose);
      // Inject a fake browser through the same embedded presenter used in production.
      final dialog = _open(host.context, token, (_) async {
        await showSourceBrowserAuthorization(
          host.context,
          {'url': 'https://site.example/login', 'completion': 'manual'},
          token,
          browserFactory: () => browser,
          dialogController: controller,
        );
        expect(browser.closed, isTrue);
      }, controller: controller);
      await tester.pumpAndSettle();
      final surface = tester.element(find.byType(Dialog));
      final initialWidth = tester.getSize(find.byType(AnimatedSize)).width;
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.text('Browser content'), findsOneWidget);
      expect(tester.element(find.byType(Dialog)), same(surface));
      expect(
        tester.getSize(find.byType(AnimatedSize)).width,
        greaterThan(initialWidth),
      );
      expect(host.observer.pushes, 2);
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Complete login'));
      await tester.pumpAndSettle();
      expect(find.text('User'), findsOneWidget);
      expect(tester.element(find.byType(Dialog)), same(surface));
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      await dialog;
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'external authorization waits and completes inside the original dialog',
    (tester) async {
      const channel = MethodChannel('hazuki/external_authorization');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'prepare') {
          return 'hazuki-auth-test://authorize/${call.arguments['id']}';
        }
        return true;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final host = await _mount(tester);
      final token = SourceLoginCancellation();
      Map<String, Object>? prepared;
      final dialog = _open(host.context, token, (present) async {
        final broker = SourceExternalAuthorizationBroker.instance;
        prepared = await broker.prepare({
          'allowedSchemes': ['mock-provider'],
        }, token);
        try {
          final answer = await present({
            'type': 'externalAuthorization',
            'id': prepared!['id'],
            'url': 'mock-provider://login',
            'title': 'Authorize',
          }, token);
          expect((answer as Map)['status'], 'completed');
        } finally {
          await broker.close(prepared!['id'] as String, token);
        }
      });
      await tester.pumpAndSettle();
      final surface = tester.element(find.byType(Dialog));
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Authorize'), findsOneWidget);
      expect(tester.element(find.byType(Dialog)), same(surface));
      expect(host.observer.pushes, 2);
      final delivered = Completer<void>();
      await messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          MethodCall('callback', '${prepared!['callbackUrl']}?code=synthetic'),
        ),
        (_) => delivered.complete(),
      );
      await delivered.future;
      await tester.pumpAndSettle();
      expect(find.text('User'), findsOneWidget);
      expect(tester.element(find.byType(Dialog)), same(surface));
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      await dialog;
      expect(tester.takeException(), isNull);
    },
  );
}

Future<({BuildContext context, _Observer observer})> _mount(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
}) async {
  late BuildContext context;
  final observer = _Observer();
  await tester.pumpWidget(
    SourceImageGatewayScope(
      gateway: const _Images(),
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        navigatorObservers: [observer],
        home: Builder(
          builder: (c) {
            context = c;
            return const Scaffold(body: Text('Home'));
          },
        ),
      ),
    ),
  );
  return (context: context, observer: observer);
}

Future<void> _open(
  BuildContext context,
  SourceLoginCancellation token,
  Future<void> Function(SourceLoginPresenter present) login, {
  SourceLoginDialogController? controller,
  String input = 'none',
}) => showHomeLoginDialog(
  context,
  interactionController: controller,
  initialUsername: '',
  initialAvatarUrl: '',
  firstUseText: '',
  loginMethods: [SourceLoginMethod(id: 'test', title: 'Test', input: input)],
  onLogin: (_, _) async => throw StateError('legacy'),
  onLoginMethod: (_, _, _, present) async {
    await login(present);
    return const HomeLoginDialogProfile(username: 'User', avatarUrl: '');
  },
  onDismissed: token.cancel,
  onLogoutTap: () {},
  onRequestSaveAvatar: (_) async {},
);

class _Observer extends NavigatorObserver {
  int pushes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => pushes++;
}

class _Browser implements SourceAuthorizationBrowser {
  final ready = Completer<void>();
  bool closed = false;
  @override
  Future<void> prepare(SourceBrowserAuthorizationSession session) async {
    await ready.future;
    session.setLoading(false);
  }

  @override
  Widget build(BuildContext context) => const Text('Browser content');
  @override
  Future<void> close() async => closed = true;
}

class _Images implements SourceImageGateway {
  const _Images();
  @override
  String get activeSourceKey => 'test';
  @override
  Uint8List? peekImageBytesFromMemory(String url, {String sourceKey = ''}) =>
      null;
  @override
  Future<Uint8List> downloadImageBytes(
    String url, {
    String comicId = '',
    String epId = '',
    bool keepInMemory = false,
    bool useDiskCache = true,
    bool priority = false,
    String sourceKey = '',
  }) async => throw StateError('Unexpected image request');
}
