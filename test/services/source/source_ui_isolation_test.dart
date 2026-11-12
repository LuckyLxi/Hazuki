import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/interaction/source_ui_scope.dart';
import 'package:hazuki/services/source/interaction/source_ui_service.dart';
import 'package:hazuki/services/source/models/source_script_execution.dart';
import 'package:hazuki/services/source/runtime/source_runtime_assembly.dart';
import 'package:hazuki/services/source/runtime/source_script_engine.dart';
import 'package:hazuki/services/source/runtime/source_shared_request.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'nested services do not inherit each other\'s scope or cancellation',
    () async {
      final first = SourceUiService();
      final second = SourceUiService();
      addTearDown(first.detach);
      addTearDown(second.detach);
      await first.run(() async {
        final outer = first.currentScope!;
        await second.run(() async {
          final inner = second.currentScope!;
          expect(inner, isNot(same(outer)));
          expect(first.currentScope, isNull);
          first.cancelPlugin('unrelated', 'sourceChanged');
          first.detach();
          expect(outer.available, isFalse);
          expect(inner.available, isTrue);
        });
      }, abortOnScopeCancellation: false);
    },
  );

  test(
    'engines and shared requests ignore a foreign interaction scope',
    () async {
      final first = SourceUiService();
      final second = SourceUiService();
      addTearDown(first.detach);
      addTearDown(second.detach);
      final engine = SourceScriptEngine(sourceUiService: second);
      addTearDown(engine.close);
      await first.run(() async {
        final outer = first.currentScope!;
        outer.cancel('ownerGone');
        expect(await engine.evaluate('21 * 2'), 42);
        expect(outer.runtimeIds, isEmpty);
      }, abortOnScopeCancellation: false);
      await first.run(() async {
        final outer = first.currentScope!;
        final request = SourceSharedRequest<int>(
          sourceUiService: second,
          pluginId: 'two',
          method: 'test',
          onUnavailable: () {},
          operation: (_) async {
            second.currentScope!.cancel('user');
            return 42;
          },
        );
        expect(await request.subscribe(), 42);
        expect(outer.available, isTrue);
      }, abortOnScopeCancellation: false);
    },
  );

  test('assemblies isolate presenters, queues and runtime disposal', () async {
    const catalog = [
      SourceCatalogEntry(key: 'one', name: 'One', fileName: 'one.js'),
      SourceCatalogEntry(key: 'two', name: 'Two', fileName: 'two.js'),
    ];
    final firstUi = SourceUiService();
    final secondUi = SourceUiService();
    final first = SourceRuntimeAssembly(
      sourceUiService: firstUi,
      initialCatalog: catalog,
      secureSessionStorage: MemorySourceSecureSessionStorage(),
    );
    final second = SourceRuntimeAssembly(
      sourceUiService: secondUi,
      initialCatalog: catalog,
      secureSessionStorage: MemorySourceSecureSessionStorage(),
    );
    addTearDown(() {
      first.dispose();
      second.dispose();
      firstUi.detach();
      secondUi.detach();
    });
    final firstHandle = first.testing.handleFor('one');
    final secondHandle = second.testing.handleFor('one');
    firstHandle.loadingRuntimeIds.add('same-runtime-id');
    secondHandle.loadingRuntimeIds.add('same-runtime-id');
    expect(firstHandle.sourceUiService, same(firstUi));
    expect(secondHandle.sourceUiService, same(secondUi));

    final shownFirst = <SourceDialogSession>[];
    final shownSecond = <SourceDialogSession>[];
    firstUi.presenter = (dialog) async {
      shownFirst.add(dialog);
      dialog.markShown();
      await dialog.whenClosed;
    };
    secondUi.presenter = (dialog) async {
      shownSecond.add(dialog);
      dialog.markShown();
      await dialog.whenClosed;
    };
    final releases = List.generate(3, (_) => Completer<void>());
    Future<void> open(SourceUiService ui, String plugin, int index) =>
        ui.run(() async {
          final scope = SourceUiScope.current!
            ..runtimeIds.add('same-runtime-id')
            ..pluginIds.add(plugin);
          await ui.handle(
            {
              'method': 'ui_open',
              'options': {
                'title': plugin,
                'content': <Object>[],
                'buttons': [
                  {'id': 'ok', 'text': 'OK'},
                ],
              },
            },
            SourceScriptExecution(
              taskId: 'task-$index',
              pluginId: plugin,
              method: 'test',
              uiScopeId: scope.id,
            ),
            'same-runtime-id',
            plugin,
          );
          await releases[index].future;
        });

    final a = open(firstUi, 'one', 0);
    final aCancelled = expectLater(a, throwsA(isA<SourceUiCancelled>()));
    final b = open(secondUi, 'one', 1);
    final queued = open(secondUi, 'two', 2);
    await Future<void>.delayed(Duration.zero);
    expect(shownFirst, hasLength(1));
    expect(shownSecond, hasLength(1));

    firstHandle.requestDispose();
    await firstHandle.whenDisposed;
    await aCancelled;
    expect(shownFirst.single.isClosed, isTrue);
    expect(shownSecond.single.isClosed, isFalse);
    releases[0].complete();
    releases[1].complete();
    await b;
    await Future<void>.delayed(Duration.zero);
    expect(shownSecond.map((d) => d.pluginId), ['one', 'two']);
    releases[2].complete();
    await queued;
  });
}
