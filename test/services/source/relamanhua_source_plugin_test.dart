import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/discover/state/discover_page_controller.dart';
import 'package:hazuki/services/source/plugins/source_plugin_buttons.dart';
import 'package:hazuki/services/source/plugins/source_plugin_manager.dart';
import 'package:hazuki/services/source/runtime/source_runtime_assembly.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:pointycastle/export.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sourceId = 'relamanhua';
const _comicId = 'yiquanchaoren';
const _chapterId = 'fd1b3104-c2d4-11f1-b213-fa163e02432f';
const _pngChapterId = '8ecacd4c-1be0-11e9-89fb-024352452ce0';
const _fixturePath = 'test/fixtures/source_plugins/relamanhua';

String _response(String name) =>
    File('$_fixturePath/responses/$name').readAsStringSync();

// Use an independent AES implementation to check the plugin's decryption.
List<String> _decryptImages(String name) {
  final html = _response(name);
  final blob = RegExp(
    r"var contentKey\s*=\s*'([^']+)'",
  ).firstMatch(html)!.group(1)!;
  final key = RegExp(r"var cct\s*=\s*'([^']*)'").firstMatch(html)!.group(1)!;
  final hex = blob.substring(16);
  final cipher = PaddedBlockCipher('AES/CBC/PKCS7')
    ..init(
      false,
      PaddedBlockCipherParameters<ParametersWithIV<KeyParameter>, Null>(
        ParametersWithIV(
          KeyParameter(Uint8List.fromList(utf8.encode(key))),
          Uint8List.fromList(utf8.encode(blob.substring(0, 16))),
        ),
        null,
      ),
    );
  final encrypted = Uint8List.fromList([
    for (var i = 0; i < hex.length; i += 2)
      int.parse(hex.substring(i, i + 2), radix: 16),
  ]);
  return (jsonDecode(utf8.decode(cipher.process(encrypted))) as List)
      .map((entry) => (entry as Map)['url'] as String)
      .toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late SourcePluginManager manager;
  late SourceRuntimeAssembly assembly;
  late _SiteFixtures fixtures;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('hazuki_relama_host_');
    manager = SourcePluginManager(
      directory: () async => root,
      legacyDirectories: [],
      download: (_) async => throw StateError('Unexpected plugin download'),
    );
    assembly = SourceRuntimeAssembly(
      pluginManager: manager,
      secureSessionStorage: MemorySourceSecureSessionStorage(),
    );
    fixtures = _SiteFixtures();
    await assembly.runtimeRegistry.loadActiveSourcePreference();
    await manager.importPackage(
      await File('$_fixturePath/main.js').readAsBytes(),
    );
    assembly.testing.handleFor(_sourceId).dio.httpClientAdapter = fixtures;
  });

  tearDown(() async {
    assembly.dispose();
    manager.dispose();
    await root.delete(recursive: true);
    expect(fixtures.unexpectedRequests, isEmpty);
  });

  test(
    'imports metadata and initializes in the actual host without I/O',
    () async {
      final manifest = manager.installed.single.manifest;
      expect(manifest.id, _sourceId);
      expect(manifest.version, '1.3.4');
      expect(assembly.testing.handleFor(_sourceId).runtime.engine, isNull);
      expect(
        SourcePluginButton.parseList(
          manifest.presentation['buttons'],
        ).map((button) => '${button.id}/${button.location.name}'),
        ['imageQuality/reading', 'imageQuality/reader'],
      );
      await assembly.ensureSourceInitialized(_sourceId);
      expect(assembly.sourceMetadata(_sourceId)!.supportsAccount, isTrue);
      expect(assembly.gateways.selection.runtimeState.isReady, isTrue);
      expect(fixtures.requests, isEmpty);
    },
  );

  test(
    'host search preserves source identity, ordering and pagination',
    () async {
      final search = assembly.gateways.search;
      final first = await search.searchComics(
        keyword: '一拳超人',
        page: 1,
        order: 'free',
        sourceKey: _sourceId,
      );
      expect(first.comics, hasLength(11));
      expect(first.comics.first.id, 'yiquanchaorenmaoer');
      expect(first.comics.first.sourceKey, _sourceId);
      expect(first.comics.every((comic) => comic.subTitle.isEmpty), isTrue);
      expect(first.maxPage, 1);
      final second = await search.searchComics(
        keyword: '一拳超人',
        page: 2,
        order: 'charge',
        sourceKey: _sourceId,
      );
      expect(second.comics, isEmpty);
      expect(second.maxPage, 1);
      expect(fixtures.requests.first.uri.queryParameters['free_type'], '1');
      expect(fixtures.requests.last.uri.queryParameters['free_type'], '2');
      expect(fixtures.requests.last.uri.queryParameters['offset'], '12');
    },
  );

  test(
    'host HTML bridge parses details and decrypts grouped chapters',
    () async {
      final details = await assembly.gateways.comicDetail.loadComicDetails(
        _comicId,
        sourceKey: _sourceId,
      );
      expect(details.id, _comicId);
      expect(details.sourceKey, _sourceId);
      expect(details.title, '一拳超人');
      expect(details.subTitle, isEmpty);
      expect(details.tags['作者'], ['村田雄介', 'ONE']);
      expect(details.tags['题材'], ['格鬥', '歡樂向', '冒險']);
      expect(details.infoFields.map((field) => (field.label as Map)['en']), [
        'Author',
        'Themes',
        'Aliases',
        'Status',
      ]);
      expect(details.infoFields.last.values, ['連載中']);
      expect(details.headerStats.single.text, '連載中');
      expect(details.chapters, hasLength(490));
      expect(details.chapters[_chapterId], '第286话');
      expect(
        details.chapters['9d740e5b-81ac-11f1-ae2a-fa163e02432f'],
        '其他系列 · 原作版160',
      );
      expect(details.isFavorite, isFalse);
    },
  );

  for (final sectionIndex in [0, 1]) {
    test(
      'homepage preview $sectionIndex continues from catalog page one',
      () async {
        final controller = DiscoverPageController(
          sourceService: assembly.gateways.discover,
        );
        addTearDown(controller.dispose);
        await controller.loadInitial(
          timeoutMessage: 'timeout',
          loadFailedMessage: (error) => error,
        );
        expect(controller.errorMessage, isNull);
        expect(controller.sections[sectionIndex].comics, hasLength(12));

        final pageSize = sectionIndex == 0 ? 60 : 50;
        final path = sectionIndex == 0 ? '/recommend' : '/comics';
        await controller.loadMoreSection(sectionIndex);
        expect(controller.sections[sectionIndex].comics, hasLength(pageSize));
        expect(controller.sections[sectionIndex].comics[12].id, 'catalog-12');
        expect(controller.sectionHasMore(sectionIndex), isTrue);
        await controller.loadMoreSection(sectionIndex);
        expect(
          controller.sections[sectionIndex].comics,
          hasLength(pageSize * 2),
        );
        expect(controller.sectionHasMore(sectionIndex), isFalse);
        expect(
          fixtures.requests
              .where((request) => request.uri.path == path)
              .map((request) => request.uri.queryParameters['offset']),
          ['0', '$pageSize'],
        );
      },
    );
  }

  test(
    'reader decrypts images independently and applies persisted quality',
    () async {
      final reader = assembly.gateways.reader;
      Future<List<String>> images(String chapter) => reader.loadChapterImages(
        comicId: _comicId,
        epId: chapter,
        sourceKey: _sourceId,
      );
      final expected = _decryptImages('reader.html');
      expect(expected, hasLength(14));
      expect(await images(_chapterId), expected);
      await assembly.pluginGateway.saveSetting(
        _sourceId,
        'imageQuality',
        'webp',
      );
      expect(
        await images(_chapterId),
        expected
            .map((url) => url.replaceFirst(RegExp(r'\.jpg$'), '.webp'))
            .toList(),
      );
      final png = _decryptImages('reader2.html');
      expect(
        await images(_pngChapterId),
        png
            .map((url) => url.replaceFirst(RegExp(r'\.(?:jpg|png)$'), '.webp'))
            .toList(),
      );
      await expectLater(images('missing'), throwsA(anything));
    },
  );

  test('category rankings page through the host gateway', () async {
    final category = assembly.gateways.category;
    final first = await category.loadCategoryRankingComics(
      rankingOption: '1d',
      page: 1,
    );
    final second = await category.loadCategoryRankingComics(
      rankingOption: '1d',
      page: 2,
    );
    expect(first.comics, hasLength(20));
    expect(first.comics.every((comic) => comic.subTitle.isEmpty), isTrue);
    expect(second.comics, hasLength(20));
    expect(first.comics.first.sourceKey, _sourceId);
    expect(first.comics.first.id, isNot(second.comics.first.id));
    expect(first.maxPage, greaterThan(1));
    expect(fixtures.requests.last.uri.queryParameters['offset'], '20');
  });

  test(
    'host login, secure token, favorite membership and logout agree',
    () async {
      final account = assembly.gateways.accountGateway;
      await account.login(
        account: 'fixture-user',
        password: 'fixture-password',
      );
      expect(account.isLogged, isTrue);
      final handle = assembly.testing.handleFor(_sourceId);
      expect(handle.facade.loadSourceData(_sourceId, 'token'), 'fixture-token');
      final login = fixtures.requests.singleWhere(
        (r) => r.uri.path == '/api/v1/login',
      );
      final form = Uri.splitQueryString(login.data as String);
      expect(form['username'], 'fixture-user');
      expect(
        utf8.decode(base64Decode(form['password']!)),
        'fixture-password-${form['salt']}',
      );
      expect(
        await account.loadCurrentAvatarUrl(),
        'https://s3.mangafunb.fun/user/avatar.jpg',
      );
      final favorites = assembly.gateways.favorite;
      await favorites.toggleFavorite(
        comicId: _comicId,
        isAdding: true,
        folderId: 'shelf',
        sourceKey: _sourceId,
      );
      final mutation = fixtures.requests.singleWhere(
        (r) => r.uri.path == '/api/v3/member/collect/comic',
      );
      expect(mutation.headers['Authorization'], 'Token fixture-token');
      expect(Uri.splitQueryString(mutation.data as String), {
        'comic_id': fixtures.comicUuid,
        'is_collect': '1',
      });
      final folders = await favorites.loadFavoriteFolders(
        comicId: _comicId,
        sourceKey: _sourceId,
      );
      expect(folders.errorMessage, isNull);
      expect(folders.folders.single.id, 'shelf');
      expect(folders.folders.single.name, '書架');
      expect(folders.favoritedFolderIds, contains('shelf'));
      final shelf = await favorites.loadFavoriteComics(
        page: 1,
        folderId: 'shelf',
      );
      expect(shelf.errorMessage, isNull);
      expect(shelf.comics, isNotEmpty);
      expect(shelf.comics.first.sourceKey, _sourceId);
      await account.logout();
      expect(account.isLogged, isFalse);
      expect(handle.facade.loadSourceData(_sourceId, 'token'), isNull);
    },
  );

  test(
    'missing comment routes return empty pages through host interfaces',
    () async {
      final comments = assembly.gateways.commentsGateway;
      for (final chapter in [null, _chapterId]) {
        final result = await comments.loadCommentsPage(
          comicId: _comicId,
          chapterId: chapter,
          sourceKey: _sourceId,
        );
        expect(result.comments, isEmpty);
        expect(result.maxPage, 1);
      }
    },
  );
}

class _SiteFixtures implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final unexpectedRequests = <String>[];
  String get comicUuid =>
      ((jsonDecode(_response('comic.json')) as Map)['results']
              as Map)['comic']['uuid']
          as String;

  ResponseBody _json(Object value) => ResponseBody.fromString(
    jsonEncode({'code': 200, 'message': '请求成功', 'results': value}),
    200,
    headers: {
      Headers.contentTypeHeader: ['application/json; charset=utf-8'],
    },
  );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final path = options.uri.path;
    String? fixture;
    if (path == '/' || path == '/recommend' || path == '/comics') {
      String card(int index) =>
          '<div class="exemptComicItem"><a href="/comic/catalog-$index">'
          '<img src="/cover-$index.jpg" alt="Comic $index"></a></div>';
      final offset = int.parse(options.uri.queryParameters['offset'] ?? '0');
      final pageSize = path == '/recommend' ? 60 : 50;
      final html = path == '/'
          ? '<h4 class="index-all-icon-left-txt">漫畫推薦</h4>'
                '${List.generate(12, card).join()}'
                '<h4 class="index-all-icon-left-txt">付費漫畫</h4>'
                '${List.generate(12, card).join()}'
          : '${List.generate(pageSize, (index) => card(offset + index)).join()}'
                '<span class="page-total">/2</span>';
      return ResponseBody.fromString(
        html,
        200,
        headers: {
          Headers.contentTypeHeader: ['text/html; charset=utf-8'],
        },
      );
    } else if (path == '/api/v3/search/comic') {
      fixture = options.uri.queryParameters['offset'] == '12'
          ? 'search2.json'
          : 'search.json';
    } else if (path == '/comic/$_comicId') {
      fixture = 'detail.html';
    } else if (path == '/comicdetail/$_comicId/chapters') {
      fixture = 'chapters.json';
    } else if (path == '/comic/$_comicId/chapter/$_chapterId') {
      fixture = 'reader.html';
    } else if (path == '/comic/$_comicId/chapter/$_pngChapterId') {
      fixture = 'reader2.html';
    } else if (path == '/comic/$_comicId/chapter/missing') {
      fixture = 'detail.html';
    } else if (path == '/api/v3/comic/$_comicId') {
      fixture = 'comic.json';
    } else if (path == '/api/v3/ranks') {
      fixture = options.uri.queryParameters['offset'] == '20'
          ? 'ranks2.json'
          : 'ranks.json';
    } else if (path == '/api/v1/login' || path == '/api/v2/web/user/info') {
      return _json({
        'token': 'fixture-token',
        'nickname': 'Fixture User',
        'avatar': '/user/avatar.jpg',
      });
    } else if (path == '/api/v1/logout' ||
        path == '/api/v3/member/collect/comic') {
      return _json([]);
    } else if (path == '/api/v3/member/collect/comics') {
      return _json((jsonDecode(_response('ranks.json')) as Map)['results']);
    } else if (path == '/api/v3/comments' || path == '/api/v3/roasts') {
      return ResponseBody.fromString(
        _response('comments404.html'),
        404,
        headers: {
          Headers.contentTypeHeader: ['text/html; charset=utf-8'],
        },
      );
    }
    if (fixture == null) {
      unexpectedRequests.add('${options.method} ${options.uri}');
      throw StateError('Unexpected fixture request: ${options.uri}');
    }
    return ResponseBody.fromString(
      _response(fixture),
      200,
      headers: {
        Headers.contentTypeHeader: [
          fixture.endsWith('.html')
              ? 'text/html; charset=utf-8'
              : 'application/json; charset=utf-8',
        ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
