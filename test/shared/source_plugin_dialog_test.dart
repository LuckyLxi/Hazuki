import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/app/source_runtime/source_plugin_dialog_presenter.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/source/interaction/source_ui_scope.dart';
import 'package:hazuki/services/source/interaction/source_ui_service.dart';
import 'package:hazuki/services/source/models/source_script_execution.dart';

void main() {
  testWidgets(
    'point image fits a narrow window, keeps order and clears points on refresh',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bytes = (await tester.runAsync(
        () => File(
          'assets/images/downloaded_cover_placeholder.png',
        ).readAsBytes(),
      ))!;
      final key = GlobalKey<NavigatorState>();
      final presenter = SourcePluginDialogPresenter(key);
      addTearDown(presenter.dispose);
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: key,
          navigatorObservers: [presenter],
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(),
        ),
      );
      final service = SourceUiService.instance;
      final show = service.presenter!;
      late SourceDialogSession dialog;
      service.presenter = (d) {
        dialog = d;
        return show(d);
      };
      final release = Completer<void>();
      final operation = service.run(() async {
        final scope = SourceUiScope.current!..runtimeIds.add('test');
        await service.handle(
          {
            'method': 'ui_open',
            'options': {
              'title': 'Click in order',
              'content': [
                {
                  'id': 'points',
                  'type': 'clickImage',
                  'image': bytes,
                  'pointCount': 2,
                },
              ],
              'buttons': [
                {'id': 'ok', 'text': 'OK', 'validate': true},
              ],
            },
          },
          SourceScriptExecution(
            taskId: 'test',
            pluginId: 'test',
            method: 'test',
            uiScopeId: scope.id,
          ),
          'test',
          'Plugin',
        );
        await release.future;
      });
      await tester.pump();
      for (var i = 0; i < 12; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 50));
        if (find.byType(Image).evaluate().isNotEmpty) break;
      }
      expect(find.byType(Image), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      final image = find
          .descendant(
            of: find.byKey(const ValueKey(('points', 'clickImage'))),
            matching: find.byType(GestureDetector),
          )
          .first;
      final rect = tester.getRect(image);
      await tester.tapAt(rect.center + const Offset(4, 4));
      await tester.pump();
      await tester.tapAt(rect.center - const Offset(4, 4));
      await tester.pump();
      expect((dialog.values['points'] as List).length, 2);
      final event = dialog.nextEvent();
      await tester.tap(find.text('OK'));
      final points = ((await event)['values'] as Map)['points'] as List;
      expect(
        (points.first as Map)['x'],
        greaterThan((points.last as Map)['x'] as num),
      );
      dialog.update({
        'content': [
          {
            'id': 'points',
            'type': 'clickImage',
            'image': [1, 2, 3],
            'pointCount': 2,
          },
        ],
      });
      expect(dialog.values['points'], isEmpty);
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
      expect(
        find.text('Unable to display this image. Refresh and try again.'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Close'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.byType(AlertDialog), findsOneWidget);
      release.complete();
      await operation;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'form preserves input on update, validates and closes only its dialog route',
    (tester) async {
      final key = GlobalKey<NavigatorState>();
      final presenter = SourcePluginDialogPresenter(key);
      addTearDown(presenter.dispose);
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: key,
          navigatorObservers: [presenter],
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: Text('Home')),
        ),
      );
      final service = SourceUiService.instance;
      late SourceDialogSession dialog;
      final show = service.presenter!;
      service.presenter = (value) {
        dialog = value;
        return show(value);
      };
      final release = Completer<void>();
      late SourceUiScope scope;
      final operation = service.run(() async {
        scope = SourceUiScope.current!..runtimeIds.add('test');
        await service.handle(
          {
            'method': 'ui_open',
            'options': {
              'title': 'Access',
              'content': [
                {
                  'id': 'password',
                  'type': 'input',
                  'label': 'Password',
                  'required': true,
                },
                {'id': 'message', 'type': 'text', 'text': 'Enter password'},
              ],
              'buttons': [
                {'id': 'submit', 'text': 'Continue', 'validate': true},
              ],
            },
          },
          SourceScriptExecution(
            taskId: 'test',
            pluginId: 'test',
            method: 'test',
            uiScopeId: scope.id,
          ),
          'test',
          'Test plugin',
        );
        await release.future;
      });
      await tester.pumpAndSettle();
      expect(find.text('Test plugin'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(
        find.text('Complete this field before continuing.'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), 'secret');
      dialog.update({'title': 'Try again'});
      await tester.pump();
      expect(find.text('Try again'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'secret',
      );
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      final focus = editable.focusNode;
      final selection = editable.controller.selection;
      expect(focus.hasFocus, true);
      dialog.update({
        'fieldErrors': {
          'password': {'en_US': 'Password rejected', 'zh_CN': '密码不正确'},
        },
      });
      await tester.pump();
      expect(find.text('Password rejected'), findsOneWidget);
      final updated = tester.widget<EditableText>(find.byType(EditableText));
      expect(updated.focusNode, same(focus));
      expect(updated.focusNode.hasFocus, true);
      expect(updated.controller.selection, selection);
      await tester.enterText(find.byType(TextField), 'corrected');
      await tester.pump();
      expect(find.text('Password rejected'), findsNothing);
      final event = dialog.nextEvent();
      await tester.tap(find.text('Continue'));
      expect((await event)['values'], {'password': 'corrected'});
      dialog.update({});
      await tester.pump();
      await tester.tap(find.byTooltip('Close'));
      release.complete();
      await operation;
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(await dialog.nextEvent(), {'type': 'closed', 'reason': 'user'});
    },
  );

  testWidgets(
    'a new page does not revoke plugin interaction or get popped on close',
    (tester) async {
      final key = GlobalKey<NavigatorState>();
      final presenter = SourcePluginDialogPresenter(key);
      addTearDown(presenter.dispose);
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: key,
          navigatorObservers: [presenter],
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: Text('Home')),
        ),
      );
      final operation = SourceUiService.instance.run(() async {
        final scope = SourceUiScope.current!..runtimeIds.add('test');
        final execution = SourceScriptExecution(
          taskId: 'test',
          pluginId: 'test',
          method: 'test',
          uiScopeId: scope.id,
        );
        final id = await SourceUiService.instance.handle(
          {
            'method': 'ui_open',
            'options': {
              'title': 'Notice',
              'content': [
                {'id': 'text', 'type': 'text', 'text': 'Message'},
              ],
              'buttons': [
                {'id': 'ok', 'text': 'OK'},
              ],
            },
          },
          execution,
          'test',
          'Plugin',
        );
        await SourceUiService.instance.handle(
          {'method': 'ui_next_event', 'id': id},
          execution,
          'test',
          'Plugin',
        );
      });
      await tester.pumpAndSettle();
      unawaited(
        key.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('New page')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('New page'), findsOneWidget);
      final scope = SourceUiService.instance.scopes.single;
      expect(scope.available, true);
      SourceUiService.instance.cancelRuntime('test');
      await expectLater(operation, throwsA(isA<SourceUiCancelled>()));
      await tester.pumpAndSettle();
      expect(find.text('New page'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
