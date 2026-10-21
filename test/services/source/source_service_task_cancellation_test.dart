import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/account/source_login_side_data_operations.dart';
import 'package:hazuki/services/source/account/source_relogin_coordinator.dart';
import 'package:hazuki/services/source/comments/comments_capability.dart';
import 'package:hazuki/services/source/interaction/source_ui_scope.dart';
import 'package:hazuki/services/source/interaction/source_ui_service.dart';
import 'package:hazuki/services/source/runtime/source_operation_runner.dart';
import 'package:hazuki/services/source/runtime/source_runtime_host.dart';
import 'package:hazuki/services/source/runtime/source_script_engine.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Http implements HttpClientAdapter {
  final pending = <String, Completer<ResponseBody>>{};
  final aborted = <String>{};
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    final key = options.uri.pathSegments.last;
    final result = pending[key] = Completer<ResponseBody>();
    cancelFuture?.then((_) => aborted.add(key));
    return result.future;
  }

  void complete(String key) =>
      pending[key]!.complete(ResponseBody.fromString('{}', 200));
  @override
  void close({bool force = false}) {}
}

Future<void> _until(bool Function() predicate) async {
  final clock = Stopwatch()..start();
  while (!predicate() && clock.elapsed < const Duration(seconds: 3)) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  expect(predicate(), isTrue);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SourceRuntimeHost host;
  late SourceScriptEngine engine;
  late SourceCommentsCapability comments;
  late _Http http;
  late Future<void> Function() initialize;
  late Completer<void> entered;
  SourceTaskOrigin origin(String owner) =>
      SourceTaskOrigin(ownerId: owner, groupId: 'group', requestSequence: 1);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    initialize = () async {};
    host = SourceRuntimeHost(
      catalog: const [
        SourceCatalogEntry(
          key: 'one',
          name: 'One',
          fileName: 'one.js',
          pluginVersion: '1',
        ),
        SourceCatalogEntry(key: 'two', name: 'Two', fileName: 'two.js'),
      ],
      defaultSourceKey: 'one',
      secureSessionStorage: MemorySourceSecureSessionStorage(),
      ensureSourceInitialized: (_) => initialize(),
      currentAccountForSource: (_) => null,
      isLoggedForSource: (_) => false,
    );
    addTearDown(host.dispose);
    final handle = host.activeHandle;
    await handle.facade.ensurePrefs();
    engine = SourceScriptEngine(pluginId: 'one');
    addTearDown(engine.close);
    handle.runtime.engine = engine;
    handle.runtime.sourceMeta = SourceMeta(
      name: 'One',
      key: 'one',
      version: '1',
      supportsAccount: true,
      settingsDefaults: {},
    );
    engine.operationGuard = handle.runOperation;
    http = _Http();
    entered = Completer<void>();
    handle.dio.httpClientAdapter = http;
    engine.setOperationMessageHandler((message, context) {
      final value = Map<String, dynamic>.from(message as Map);
      if (value['entered'] == true) {
        if (!entered.isCompleted) entered.complete();
        return null;
      }
      return handle.httpGateway.sendJsHttpRequest(
        value,
        hostContext: context,
        execution: context.execution,
        runtimeId: context.runtimeId,
      );
    });
    comments = SourceCommentsCapability(
      runtimeHost: host,
      reloginCoordinator: SourceReloginCoordinator(
        loginWithStoredAccount:
            (_, {required account, required password}) async {
              fail('cancellation must not invoke stored-account login');
            },
      ),
    );
  });

  Future<void> install(
    String read, {
    String write = '()=>null',
  }) => engine.execute(
    'globalThis.__hazuki_source={comic:{loadComments:$read,sendComment:$write}}',
  );

  const readHttp = '''id=>sendMessage({method:"http",http_method:"GET",
    url:"https://fixture.test/"+id}).then(()=>({comments:[],maxPage:1}))''';
  const writeHttp = '''id=>sendMessage({method:"http",http_method:"GET",
    url:"https://fixture.test/"+id}).then(()=>{globalThis.written=true;})''';

  test('cancel during initialization prevents all later commands', () async {
    final gate = Completer<void>();
    initialize = () => gate.future;
    await install('()=>{globalThis.executed=true;return {comments:[]}}');
    final pending = comments.loadCommentsPage(
      comicId: 'read',
      taskOrigin: origin('page'),
    );
    final stopped = expectLater(pending, throwsA(isA<SourceTaskCancelled>()));
    final receipt = await host.tasks.cancelOwner(
      'page',
      SourceTaskStopReason.ownerDisposed,
    );
    await stopped;
    await receipt.whenSettled;
    gate.complete();
    await Future<void>.delayed(Duration.zero);
    expect(await engine.evaluate('typeof executed'), 'undefined');
  });

  test('multiple explicit commands share one service task identity', () async {
    final identities = <String>[];
    engine.setOperationMessageHandler((_, context) {
      identities.add(context.execution.taskId);
      return null;
    });
    await runSourceOperation(host, host.activeHandle, 'fixture.multiple', (
      context,
    ) async {
      await context.evaluate(engine, 'sendMessage({})');
      await context.evaluate(engine, 'sendMessage({})');
    });
    expect(identities, hasLength(2));
    expect(identities.toSet(), hasLength(1));
  });

  test(
    'read cancellation aborts HTTP while same-source write completes',
    () async {
      await install(readHttp, write: writeHttp);
      final reading = comments.loadCommentsPage(
        comicId: 'read',
        taskOrigin: origin('page'),
      );
      final stopped = expectLater(reading, throwsA(isA<SourceTaskCancelled>()));
      final writing = comments.sendComment(comicId: 'write', content: 'text');
      await _until(() => http.pending.length == 2);
      final receipt = await host.tasks.cancelOwner(
        'page',
        SourceTaskStopReason.superseded,
      );
      await stopped;
      await receipt.whenSettled;
      expect(http.aborted, contains('read'));
      expect(http.aborted, isNot(contains('write')));
      http.complete('write');
      await writing;
      expect(await engine.evaluate('written'), isTrue);
      expect(host.activeHandle.runtime.engine, same(engine));
      http.complete('read');
    },
  );

  test('CPU cancellation preserves the same usable runtime', () async {
    await install('()=>{sendMessage({entered:true});while(true){}}');
    final pending = comments.loadCommentsPage(
      comicId: 'read',
      taskOrigin: origin('page'),
    );
    final stopped = expectLater(pending, throwsA(isA<SourceTaskCancelled>()));
    await entered.future.timeout(const Duration(seconds: 3));
    final receipt = await host.tasks.cancelOwner(
      'page',
      SourceTaskStopReason.user,
    );
    await stopped.timeout(const Duration(seconds: 3));
    await receipt.whenSettled.timeout(const Duration(seconds: 3));
    expect(await engine.evaluate('42'), 42);
  });

  test(
    'cancel removes an exclusive worker Timer and its continuation',
    () async {
      await install('''()=>{sendMessage({entered:true});
      globalThis.continued=false;return sendMessage({method:"delay",time:60000})
      .then(()=>{continued=true;return {comments:[]}})}''');
      final pending = comments.loadCommentsPage(
        comicId: 'read',
        taskOrigin: origin('page'),
      );
      final stopped = expectLater(pending, throwsA(isA<SourceTaskCancelled>()));
      await entered.future;
      final receipt = await host.tasks.cancelOwner(
        'page',
        SourceTaskStopReason.ownerDisposed,
      );
      await stopped;
      await receipt.whenSettled.timeout(const Duration(seconds: 3));
      expect(await engine.evaluate('continued'), isFalse);
    },
  );

  test(
    'page disposal revokes UI but lets accepted service HTTP finish',
    () async {
      await install(readHttp, write: writeHttp);
      final owner = SourceUiOwner();
      final pending = owner.run(
        () => comments.sendComment(comicId: 'write', content: 'text'),
      );
      final detached = expectLater(pending, throwsA(isA<SourceUiCancelled>()));
      await _until(() => http.pending.containsKey('write'));
      owner.dispose();
      await detached;
      expect(http.aborted, isNot(contains('write')));
      http.complete('write');
      await _until(() => host.tasks.activeTasks.isEmpty);
      expect(await engine.evaluate('written'), isTrue);
    },
  );

  test('revoked service UI cannot authorize a later prompt', () async {
    final gate = Completer<void>();
    final owner = SourceUiOwner();
    SourceUiScope? authority;
    final pending = owner.run(
      () => runSourceOperation(host, host.activeHandle, 'fixture.write', (
        context,
      ) async {
        authority = SourceUiScope.current;
        await gate.future;
        if (authority?.available != true) {
          throw const SourceUiCancelled('ownerGone');
        }
        fail('a disposed page must not grant new UI');
      }, serviceOwned: true),
    );
    final detached = expectLater(pending, throwsA(isA<SourceUiCancelled>()));
    await _until(() => authority != null);
    owner.dispose();
    await detached;
    expect(authority!.available, isFalse);
    gate.complete();
    await _until(() => host.tasks.activeTasks.isEmpty);
  });

  test('accepted Dart commit drains before cancellation settles', () async {
    final started = Completer<void>();
    final commit = Completer<void>();
    var nextWrite = false;
    final pending = runSourceOperation(
      host,
      host.activeHandle,
      'fixture.commit',
      (context) async {
        await context.commit(() {
          started.complete();
          return commit.future;
        });
        await context.commit(() async {
          nextWrite = true;
        });
      },
      origin: origin('write'),
      serviceOwned: true,
    );
    final stopped = expectLater(pending, throwsA(isA<SourceTaskCancelled>()));
    await started.future;
    final receipt = await host.tasks.cancelOwner(
      'write',
      SourceTaskStopReason.pluginDisabled,
    );
    await stopped;
    var settled = false;
    receipt.whenSettled.then((_) => settled = true);
    await Future<void>.delayed(Duration.zero);
    expect(settled, isFalse);
    commit.complete();
    await receipt.whenSettled;
    expect(nextWrite, isFalse);
  });

  test('switching source retains an already accepted write lease', () async {
    await install(readHttp, write: writeHttp);
    final old = host.activeHandle;
    final pending = comments.sendComment(comicId: 'write', content: 'text');
    await _until(() => http.pending.containsKey('write'));
    await host.activateSource('two');
    expect(old.isDisposed, isFalse);
    expect(http.aborted, isNot(contains('write')));
    http.complete('write');
    await pending;
    await old.whenDisposed;
  });

  test(
    'plugin replacement stops the old handle and preserves the new one',
    () async {
      await install(readHttp);
      final pending = comments.loadCommentsPage(
        comicId: 'read',
        taskOrigin: origin('page'),
      );
      final stopped = expectLater(
        pending,
        throwsA(
          isA<SourceTaskCancelled>().having(
            (e) => e.reason,
            'reason',
            SourceTaskStopReason.pluginUpdated,
          ),
        ),
      );
      await _until(() => http.pending.containsKey('read'));
      await host.replaceCatalog(const [
        SourceCatalogEntry(
          key: 'one',
          name: 'One',
          fileName: 'one.js',
          pluginVersion: '2',
        ),
      ]);
      final replacement = SourceScriptEngine(pluginId: 'one');
      addTearDown(replacement.close);
      host.activeHandle.runtime.engine = replacement;
      await stopped;
      await _until(() => http.aborted.contains('read'));
      await host.tasks.cancelOwner('page', SourceTaskStopReason.ownerDisposed);
      expect(await replacement.evaluate('42'), 42);
      http.complete('read');
    },
  );

  test('one profile subscriber cancels without stopping the other', () async {
    await engine.execute(
      'globalThis.__hazuki_source={account:{loadProfile:()=>'
      'sendMessage({method:"http",http_method:"GET",url:"https://fixture.test/profile"})'
      '.then(()=>({avatarUrl:"https://fixture.test/avatar"}))}}',
    );
    final profiles = SourceLoginSideDataOperations(runtimeHost: host);
    final first = profiles.loadCurrentAvatarUrl(taskOrigin: origin('first'));
    final stopped = expectLater(first, throwsA(isA<SourceTaskCancelled>()));
    final second = profiles.loadCurrentAvatarUrl(taskOrigin: origin('second'));
    await _until(() => http.pending.containsKey('profile'));
    final receipt = await host.tasks.cancelOwner(
      'first',
      SourceTaskStopReason.ownerDisposed,
    );
    await stopped;
    await receipt.whenSettled;
    expect(receipt.sharedResourceCount, 1);
    expect(http.aborted, isEmpty);
    http.complete('profile');
    expect(await second, 'https://fixture.test/avatar');
  });

  test(
    'last profile subscriber stops its producer and prevents late cache',
    () async {
      await engine.execute(
        'globalThis.__hazuki_source={account:{loadProfile:()=>'
        'sendMessage({method:"http",http_method:"GET",url:"https://fixture.test/profile"})'
        '.then(()=>({avatarUrl:"late"}))}}',
      );
      final profiles = SourceLoginSideDataOperations(runtimeHost: host);
      final pending = profiles.loadCurrentAvatarUrl(taskOrigin: origin('page'));
      final stopped = expectLater(pending, throwsA(isA<SourceTaskCancelled>()));
      await _until(() => http.pending.containsKey('profile'));
      final receipt = await host.tasks.cancelOwner(
        'page',
        SourceTaskStopReason.ownerDisposed,
      );
      await stopped;
      await receipt.whenSettled;
      expect(http.aborted, contains('profile'));
      http.complete('profile');
      await Future<void>.delayed(Duration.zero);
      expect(profiles.cachedAvatarUrl, isNull);
    },
  );
  test(
    'successful service tasks retain cancellable residual Timer ownership',
    () async {
      await install(
        '()=>({comments:[]})',
        write: """()=>{
      globalThis.residualContinued=false;
      sendMessage({method:"delay",time:60000}).then(()=>{residualContinued=true;});
      return null;
    }""",
      );
      await comments.sendComment(comicId: 'write', content: 'text');
      expect(host.tasks.activeTasks, isEmpty);
      final receipt = await host.tasks.cancelOwner(
        host.serviceTaskOwnerId,
        SourceTaskStopReason.ownerDisposed,
      );
      expect(receipt.status, SourceTaskCancelStatus.accepted);
      await receipt.whenSettled.timeout(const Duration(seconds: 3));
      expect(await engine.evaluate('residualContinued'), isFalse);
    },
  );

  test(
    'read cancellation detaches independent session maintenance without replay',
    () async {
      final handle = host.activeHandle;
      await handle.facade.saveSourceData('one', 'account', [
        'account',
        'password',
      ]);
      final maintenance = Completer<void>();
      final maintenanceStarted = Completer<void>();
      final coordinator = SourceReloginCoordinator(
        loginWithStoredAccount: (_, {required account, required password}) =>
            runSourceOperation(host, handle, 'account.maintenance', (
              context,
            ) async {
              maintenanceStarted.complete();
              await context.resolve(maintenance.future);
            }, serviceOwned: true),
      );
      var attempts = 0;
      final reading = runSourceOperation(
        host,
        handle,
        'fixture.authenticatedRead',
        (context) => coordinator.runWithReloginRetry(
          () async {
            attempts++;
            throw StateError('401');
          },
          context: SourceFacadeReloginContext(handle.facade),
          checkActive: context.checkActive,
        ),
        origin: origin('page'),
      );
      final stopped = expectLater(reading, throwsA(isA<SourceTaskCancelled>()));
      await maintenanceStarted.future;
      final receipt = await host.tasks.cancelOwner(
        'page',
        SourceTaskStopReason.superseded,
      );
      await stopped;
      await receipt.whenSettled.timeout(const Duration(seconds: 3));
      expect(host.tasks.activeTasks.single.method, 'account.maintenance');
      maintenance.complete();
      await _until(() => host.tasks.activeTasks.isEmpty);
      expect(attempts, 1);
    },
  );
  test(
    'page exit permits the next admitted noninteractive service command',
    () async {
      final owner = SourceUiOwner();
      final gate = Completer<void>();
      final betweenCommands = Completer<void>();
      final pending = owner.run(
        () => runSourceOperation(
          host,
          host.activeHandle,
          'fixture.multiCommandWrite',
          (context) async {
            await context.evaluate(engine, 'globalThis.serviceSecond=false');
            betweenCommands.complete();
            await gate.future;
            await context.evaluate(engine, 'serviceSecond=true');
          },
          serviceOwned: true,
        ),
      );
      final detached = expectLater(pending, throwsA(isA<SourceUiCancelled>()));
      await betweenCommands.future;
      owner.dispose();
      await detached;
      gate.complete();
      await _until(() => host.tasks.activeTasks.isEmpty);
      expect(await engine.evaluate('serviceSecond'), isTrue);
    },
  );
  test('plugin disable records its reason before revoking page UI', () async {
    await install(readHttp);
    final owner = SourceUiOwner();
    late Future<ComicCommentsPageResult> serviceRead;
    final pending = owner.run(() {
      serviceRead = comments.loadCommentsPage(
        comicId: 'read',
        taskOrigin: SourceTaskOrigin(
          ownerId: 'page',
          groupId: 'query',
          requestSequence: 1,
          cancellation: SourceTaskCancellation(),
        ),
      );
      return serviceRead;
    });
    final stopped = expectLater(
      serviceRead,
      throwsA(
        isA<SourceTaskCancelled>().having(
          (error) => error.reason,
          'reason',
          SourceTaskStopReason.pluginDisabled,
        ),
      ),
    );
    final pageStopped = expectLater(
      pending,
      throwsA(anyOf(isA<SourceUiCancelled>(), isA<SourceTaskCancelled>())),
    );
    await _until(() => http.pending.containsKey('read'));
    await host.replaceCatalog(const []);
    await stopped;
    await pageStopped;
    await _until(() => http.aborted.contains('read'));
    owner.dispose();
    http.complete('read');
  });
}
