import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/account/source_login_interaction.dart';
import 'package:hazuki/services/source/interaction/source_dialog_model.dart';
import 'package:hazuki/services/source/interaction/source_ui_scope.dart';
import 'package:hazuki/services/source/interaction/source_ui_service.dart';
import 'package:hazuki/services/source/models/source_script_execution.dart';

Map<String, Object?> options() => {
  'title': 'Form',
  'content': [
    {'id': 'name', 'type': 'input', 'label': 'Name', 'required': true},
    {'id': 'enabled', 'type': 'toggle', 'label': 'Enabled'},
  ],
  'buttons': [
    {'id': 'refresh', 'text': 'Refresh'},
    {'id': 'submit', 'text': 'Submit', 'validate': true},
  ],
};

SourceScriptExecution execution(
  SourceUiScope scope, {
  String plugin = 'test',
}) => SourceScriptExecution(
  taskId: 'task',
  pluginId: plugin,
  method: 'action',
  uiScopeId: scope.id,
);

void main() {
  test('browser user cancellation revokes its task scope', () async {
    final service = SourceUiService();
    addTearDown(service.detach);
    service.presenter = (_) async => throw const SourceLoginCancelled();
    const task = SourceScriptExecution(
      taskId: 'cancelled-browser',
      pluginId: 'test',
      method: 'download',
    );
    await expectLater(
      service.runBrowserAuthorization(
        () => service.handle(
          {
            'method': 'ui_browser',
            'options': {'url': 'https://site.example/', 'completion': 'manual'},
          },
          task,
          'engine',
          'Test',
        ),
        execution: task,
        runtimeId: 'engine',
        timeout: const Duration(minutes: 5),
      ),
      throwsA(
        isA<SourceUiCancelled>().having((e) => e.reason, 'reason', 'user'),
      ),
    );
    expect(service.scopes.single.reason, 'user');
    service.releaseExecution(task, 'engine');
    await Future<void>.delayed(Duration.zero);
    expect(service.scopes, isEmpty);
  });

  test(
    'browser authorization survives system activities and waits for foreground before continuing',
    () async {
      final service = SourceUiService();
      final browser = Completer<String>();
      late SourceUiScope scope;
      late SourceScriptExecution task;
      var continued = false;
      final running = service.run(() async {
        scope = SourceUiScope.current!..runtimeIds.add('engine');
        task = execution(scope);
        final value = await service.runBrowserAuthorization(
          () => browser.future,
          execution: task,
          runtimeId: 'engine',
          timeout: const Duration(seconds: 5),
        );
        service.checkExecution(task, 'engine');
        continued = true;
        return value;
      });
      service.setForeground(false);
      service.setForeground(false);
      expect(scope.available, true);
      expect(
        () => service.checkExecution(task, 'engine'),
        throwsA(isA<SourceUiCancelled>()),
      );
      browser.complete('authorized');
      await Future<void>.delayed(Duration.zero);
      expect(continued, false);
      service.setForeground(true);
      expect(await running, 'authorized');
      expect(continued, true);
    },
  );

  for (final reason in ['user', 'ownerGone', 'runtimeDisposed']) {
    test('browser suspension still respects cancellation: $reason', () async {
      final service = SourceUiService();
      final browser = Completer<String>();
      late SourceUiScope scope;
      final running = service.run(() async {
        scope = SourceUiScope.current!..runtimeIds.add('engine');
        return service.runBrowserAuthorization(
          () => browser.future,
          execution: execution(scope),
          runtimeId: 'engine',
          timeout: const Duration(seconds: 5),
        );
      });
      final rejected = expectLater(running, throwsA(isA<SourceUiCancelled>()));
      service.setForeground(false);
      if (reason == 'runtimeDisposed') {
        service.cancelRuntime('engine');
      } else {
        scope.cancel(reason);
      }
      await rejected;
      browser.complete('late');
      service.setForeground(true);
    });
  }

  test(
    'browser completion in background cannot extend the authorization deadline',
    () async {
      final service = SourceUiService();
      final browser = Completer<String>();
      final running = service.run(() async {
        final scope = SourceUiScope.current!..runtimeIds.add('engine');
        return service.runBrowserAuthorization(
          () => browser.future,
          execution: execution(scope),
          runtimeId: 'engine',
          timeout: Duration.zero,
        );
      });
      final rejected = expectLater(
        running,
        throwsA(
          isA<SourceUiCancelled>().having(
            (error) => error.reason,
            'reason',
            'timeout',
          ),
        ),
      );
      service.setForeground(false);
      browser.complete('authorized');
      await rejected;
      service.setForeground(true);
    },
  );

  test(
    'interaction cancellation keeps plain loads but stops browser authorization',
    () async {
      final service = SourceUiService();
      final load = Completer<String>();
      final browser = Completer<String>();
      final plain = service.run(() => load.future);
      final authorizing = service.run(() async {
        final scope = SourceUiScope.current!..runtimeIds.add('engine');
        return service.runBrowserAuthorization(
          () => browser.future,
          execution: execution(scope),
          runtimeId: 'engine',
          timeout: const Duration(seconds: 5),
        );
      });
      final rejected = expectLater(
        authorizing,
        throwsA(
          isA<SourceUiCancelled>().having(
            (e) => e.reason,
            'reason',
            'ownerGone',
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      service.cancelInteractions('ownerGone');
      await rejected;
      load.complete('sections');
      expect(await plain, 'sections');
      browser.complete('late');
    },
  );

  test('background callers can create an interaction scope', () async {
    final service = SourceUiService();
    await SourceUiScope.withoutInteraction(
      () => service.run(() async {
        expect(SourceUiScope.current, isNotNull);
        expect(service.scopes, hasLength(1));
      }),
    );
  });

  test(
    'source cancellation revokes work before any dialog and rejects late HTTP',
    () async {
      final service = SourceUiService();
      final pending = Completer<void>();
      late SourceScriptExecution task;
      final running = service.run(() async {
        final scope = SourceUiScope.current!
          ..runtimeIds.add('engine')
          ..pluginIds.add('plugin');
        task = execution(scope);
        await pending.future;
      });
      final rejected = expectLater(running, throwsA(isA<SourceUiCancelled>()));
      service.cancelPlugin('plugin', 'sourceChanged');
      await rejected;
      expect(
        () => service.checkExecution(task, 'engine'),
        throwsA(isA<SourceUiCancelled>()),
      );
      pending.complete();
    },
  );
  test('validates descriptors, images, ids and values before use', () {
    final raw = options();
    expect(SourceDialogModel.parse(raw).initialValues, {
      'name': '',
      'enabled': false,
    });
    for (final content in [
      [
        {'id': 'x', 'type': 'unknown'},
      ],
      [
        {'id': 'x', 'type': 'input', 'label': 'x', 'initialValue': false},
      ],
      [
        {'id': 'x', 'type': 'image', 'image': 'https://example.com/image'},
      ],
      [
        {
          'id': 'x',
          'type': 'clickImage',
          'image': [1],
          'pointCount': 33,
        },
      ],
      [
        {'id': 'x', 'type': 'text', 'text': 'x'},
        {'id': 'x', 'type': 'text', 'text': 'y'},
      ],
      [
        {
          'id': 'x',
          'type': 'select',
          'label': 'x',
          'options': [
            {'value': 'a', 'label': 'A'},
            {'value': 'a', 'label': 'B'},
          ],
        },
      ],
    ]) {
      expect(
        () => SourceDialogModel.parse({...raw, 'content': content}),
        throwsFormatException,
      );
    }
  });

  test(
    'work timeout remains a work error and queued dialogs have a bounded wait',
    () async {
      final service = SourceUiService(
        queueTimeout: const Duration(milliseconds: 25),
      );
      service.presenter = (_) async =>
          fail('queued dialog must not be displayed');
      service.canPresent = (_) => false;
      await expectLater(
        service.run(() async {
          final scope = SourceUiScope.current!..runtimeIds.add('engine');
          await service.handle(
            {'method': 'ui_open', 'options': options()},
            execution(scope),
            'engine',
            'Plugin',
          );
        }),
        throwsA(
          isA<SourceUiCancelled>().having((e) => e.reason, 'reason', 'timeout'),
        ),
      );
      await expectLater(
        service.run(
          () => SourceUiScope.timeout(
            Completer<void>().future,
            const Duration(milliseconds: 25),
          ),
        ),
        throwsA(isA<TimeoutException>()),
      );
    },
  );

  test(
    'updates preserve values, reject atomically and freeze repeated actions',
    () async {
      final service = SourceUiService();
      late SourceDialogSession dialog;
      service.presenter = (value) async {
        dialog = value;
        value.markShown();
        await value.whenClosed;
      };
      await service.run(() async {
        final scope = SourceUiScope.current!..runtimeIds.add('engine');
        final call = execution(scope);
        final id = await service.handle(
          {'method': 'ui_open', 'options': options()},
          call,
          'engine',
          'Plugin',
        );
        dialog.action('submit');
        expect(dialog.fieldErrors, contains('name'));
        expect(dialog.busy, false);
        dialog.setValue('name', 'Alice');
        final event = dialog.nextEvent();
        expect(() => dialog.nextEvent(), throwsStateError);
        dialog.action('submit');
        dialog.action('submit');
        expect((await event)['values'], {'name': 'Alice', 'enabled': false});
        expect(dialog.busy, true);
        expect(
          () => dialog.update({
            'values': {'enabled': 'wrong'},
          }),
          throwsFormatException,
        );
        expect(dialog.values['name'], 'Alice');
        expect(dialog.busy, true);
        dialog.update({'title': 'Retry'});
        expect(dialog.values['name'], 'Alice');
        expect(dialog.busy, false);
        dialog.update({
          'fieldErrors': {
            'name': {'en_US': 'Name rejected', 'zh_CN': '名称不可用'},
            'enabled': 'Accept the terms',
          },
        });
        expect(dialog.fieldErrors, hasLength(2));
        final errors = Map<String, Object?>.from(dialog.fieldErrors);
        for (final invalid in [
          {'missing': 'Error'},
          {'name': false},
          {'name': <String, Object>{}},
        ]) {
          expect(
            () => dialog.update({'title': 'Invalid', 'fieldErrors': invalid}),
            throwsFormatException,
          );
          expect(dialog.model.title, 'Retry');
          expect(dialog.fieldErrors, errors);
        }
        dialog.setValue('name', 'Bob');
        expect(dialog.fieldErrors.keys, ['enabled']);
        dialog.update({
          'fieldErrors': {'name': 'Try again', 'enabled': null},
        });
        expect(dialog.fieldErrors, {'name': 'Try again'});
        dialog.update({});
        expect(dialog.fieldErrors, isEmpty);
        dialog.update({
          'values': {'name': ''},
        });
        expect(dialog.values['name'], '');
        expect(
          () => service.handle(
            {'method': 'ui_close', 'id': id},
            execution(scope, plugin: 'other'),
            'engine',
            'Other',
          ),
          throwsStateError,
        );
        expect(
          () => service.handle(
            {'method': 'ui_close', 'id': id},
            call,
            'another-engine',
            'Plugin',
          ),
          throwsStateError,
        );
        final waiting = dialog.nextEvent();
        dialog.close('plugin');
        expect(await waiting, {'type': 'closed', 'reason': 'plugin'});
        expect(await dialog.nextEvent(), {
          'type': 'closed',
          'reason': 'plugin',
        });
        dialog.close('plugin');
        expect(() => dialog.update({}), throwsStateError);
      });
    },
  );

  test(
    'queues different operations and revokes a queued owner without showing it',
    () async {
      final service = SourceUiService();
      final shown = <SourceDialogSession>[];
      final firstShown = Completer<void>();
      service.presenter = (dialog) async {
        shown.add(dialog);
        dialog.markShown();
        if (!firstShown.isCompleted) firstShown.complete();
        await dialog.whenClosed;
      };
      final release = Completer<void>();
      final first = service.run(() async {
        final scope = SourceUiScope.current!..runtimeIds.add('one');
        await service.handle(
          {'method': 'ui_open', 'options': options()},
          execution(scope),
          'one',
          'One',
        );
        await release.future;
      });
      await firstShown.future;
      late SourceUiScope queuedScope;
      final queued = service.run(() async {
        queuedScope = SourceUiScope.current!..runtimeIds.add('two');
        await service.handle(
          {'method': 'ui_open', 'options': options()},
          execution(queuedScope),
          'two',
          'Two',
        );
      });
      final expected = expectLater(queued, throwsA(isA<SourceUiCancelled>()));
      queuedScope.cancel('superseded');
      await expected;
      release.complete();
      await first;
      await Future<void>.delayed(Duration.zero);
      expect(shown.length, 1);
      expect(shown.single.isClosed, true);
    },
  );

  test(
    'human waiting pauses work timeout, updates do not reset interaction budget',
    () async {
      final service = SourceUiService(
        interactionTimeout: const Duration(milliseconds: 220),
      );
      late SourceDialogSession dialog;
      service.presenter = (value) async {
        dialog = value;
        value.markShown();
        await value.whenClosed;
      };
      final shown = Completer<void>();
      final work = service.run(() async {
        final scope = SourceUiScope.current!..runtimeIds.add('engine');
        final operation = () async {
          await service.handle(
            {'method': 'ui_open', 'options': options()},
            execution(scope),
            'engine',
            'Plugin',
          );
          shown.complete();
          await dialog.nextEvent();
        }();
        await SourceUiScope.timeout(
          operation,
          const Duration(milliseconds: 40),
        );
      });
      final expected = expectLater(work, throwsA(isA<SourceUiCancelled>()));
      await shown.future;
      await Future<void>.delayed(const Duration(milliseconds: 90));
      expect(dialog.isClosed, false);
      dialog.update({'title': 'Still waiting'});
      await expected;
      expect(await dialog.nextEvent(), {'type': 'closed', 'reason': 'timeout'});
    },
  );

  test(
    'background execution retains interaction and runtime teardown cancels work',
    () async {
      final service = SourceUiService();
      service.presenter = (_) async {};
      await service
          .run(() async {
            final scope = SourceUiScope.current!..runtimeIds.add('engine');
            expect(scope.available, true);
            await SourceUiScope.withoutInteraction(() async {
              expect(SourceUiScope.current, isNull);
            });
            expect(
              service.handle(
                {'method': 'ui_available'},
                execution(scope),
                'engine',
                'Plugin',
              ),
              true,
            );
            service.setForeground(false);
            expect(scope.available, true);
            service.cancelRuntime('engine');
          })
          .then<void>(
            (_) => fail('runtime teardown must cancel the operation'),
            onError: (Object e) {
              expect(e, isA<SourceUiCancelled>());
            },
          );
    },
  );
}
