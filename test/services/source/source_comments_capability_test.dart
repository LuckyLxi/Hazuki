import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/models/source_meta.dart';
import 'package:hazuki/services/source/account/source_relogin_coordinator.dart';
import 'package:hazuki/services/source/comments/comments_capability.dart';
import 'package:hazuki/services/source/runtime/source_runtime_host.dart';
import 'package:hazuki/services/source/runtime/source_script_engine.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SourceRuntimeHost host;
  late SourceCommentsCapability comments;
  late SourceScriptEngine target;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    host = SourceRuntimeHost(
      catalog: const [
        SourceCatalogEntry(
          key: 'active',
          name: 'Active',
          fileName: 'active.js',
        ),
        SourceCatalogEntry(
          key: 'target',
          name: 'Target',
          fileName: 'target.js',
          presentation: {
            'commentOrders': {
              'new': 'Newest',
              'hot': {'en': 'Popular', 'zh': '热门'},
            },
            'commentDefaultOrder': 'hot',
          },
        ),
      ],
      defaultSourceKey: 'active',
      secureSessionStorage: MemorySourceSecureSessionStorage(),
      ensureSourceInitialized: (_) async {},
      currentAccountForSource: (_) => null,
      isLoggedForSource: (_) => false,
    );
    comments = SourceCommentsCapability(
      runtimeHost: host,
      reloginCoordinator: SourceReloginCoordinator(
        loginWithStoredAccount:
            (_, {required account, required password}) async {},
      ),
    );
    target = SourceScriptEngine(hostPromiseRejectionHandler: (_) {});
    host.handleFor('target').runtime.engine = target;
    target.evaluate('''
      globalThis.calls = [];
      globalThis.__hazuki_source = {comic: {
        loadComments: async (...args) => {
          calls.push(['comic', ...args]);
          return {comments: [{id: args[4], content: args[4]}], maxPage: 3};
        },
        loadChapterComments: async (...args) => {
          calls.push(['chapter', ...args]);
          return {comments: [], maxPage: 1};
        }
      }};
    ''');
    addTearDown(host.dispose);
  });

  test(
    'passes normalized order after replyTo for comic and chapter requests',
    () async {
      final result = await comments.loadCommentsPage(
        comicId: 'comic"id',
        subId: 'sub',
        sourceKey: 'target',
        page: 2,
        replyTo: 'parent',
        order: 'new',
      );
      expect(result.comments.single.id, 'new');
      expect(result.maxPage, 3);
      await comments.loadCommentsPage(
        comicId: 'comic',
        chapterId: 'chapter',
        sourceKey: 'target',
        page: 3,
        replyTo: 'reply',
        order: 'missing',
      );
      expect(jsonDecode(target.evaluate('JSON.stringify(calls)') as String), [
        ['comic', 'comic"id', 'sub', 2, 'parent', 'new'],
        ['chapter', 'comic', 'chapter', 3, 'reply', 'hot'],
      ]);
      expect(host.activeSourceKey, 'active');
      expect(comments.commentSortOptionsForSource('').orders, isEmpty);
    },
  );

  test(
    'runtime declarations override installed fields and retain the default',
    () async {
      host.handleFor('target').runtime.sourceMeta = const SourceMeta(
        name: 'Target',
        key: 'target',
        version: '1',
        supportsAccount: false,
        settingsDefaults: {},
        presentation: {
          'commentOrders': {'runtime': 'Runtime', 'hot': 'Popular'},
        },
      );
      final options = comments.commentSortOptionsForSource('target');
      expect(options.orders.keys, ['runtime', 'hot']);
      expect(options.defaultOrder, 'hot');
      final result = await comments.loadComments(
        comicId: 'comic',
        sourceKey: 'target',
        order: 'runtime',
      );
      expect(result.single.id, 'runtime');
    },
  );

  test(
    'undeclared orders pass empty value and old four-argument plugins work',
    () async {
      host.handleFor('target').runtime.sourceMeta = const SourceMeta(
        name: 'Target',
        key: 'target',
        version: '1',
        supportsAccount: false,
        settingsDefaults: {},
        presentation: {'commentOrders': {}},
      );
      await comments.loadCommentsPage(
        comicId: 'comic',
        sourceKey: 'target',
        order: 'new',
      );
      expect(jsonDecode(target.evaluate('JSON.stringify(calls)') as String), [
        ['comic', 'comic', null, 1, null, ''],
      ]);
      target.evaluate('''
      this.__hazuki_source.comic.loadComments = async (id, subId, page, replyTo) =>
        ({comments: [{content: [id, subId, page, replyTo].join('|')}], maxPage: 1});
    ''');
      final result = await comments.loadCommentsPage(
        comicId: 'comic',
        subId: 'sub',
        sourceKey: 'target',
        page: 2,
        replyTo: 'parent',
      );
      expect(result.comments.single.content, 'comic|sub|2|parent');
    },
  );
}
