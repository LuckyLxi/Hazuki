import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('services do not depend on feature implementations', () {
    final violations = <String>[];
    for (final file in _dartFilesUnder('lib/services')) {
      final content = file.readAsStringSync();
      final hasFeatureImport = content
          .split('\n')
          .any(
            (line) =>
                line.trimLeft().startsWith('import ') &&
                line.contains('features/'),
          );
      if (hasFeatureImport) violations.add(file.path);
    }
    expect(violations, isEmpty, reason: 'service -> feature: $violations');
  });

  test('services do not import the app layer', () {
    final violations = <String>[];
    for (final file in _dartFilesUnder('lib/services')) {
      for (final line in file.readAsLinesSync()) {
        if (!line.trimLeft().startsWith('import ')) continue;
        final normalized = line.replaceAll('\\', '/');
        if (normalized.contains('/app/') ||
            normalized.contains("'../app/") ||
            normalized.contains("'../../app/")) {
          violations.add('${file.path}: $line');
        }
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('source gateways do not import runtime implementations', () {
    final violations = <String>[];
    for (final file in _dartFilesUnder('lib/services/source/gateways')) {
      for (final line in file.readAsLinesSync()) {
        if (line.contains('source_runtime_assembly.dart') ||
            line.contains('source_runtime_capability.dart')) {
          violations.add('${file.path}: $line');
        }
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('source runtime components do not import the source assembly', () {
    final violations = <String>[];
    for (final directory in const [
      'lib/services/source/runtime',
      'lib/services/source/http',
      'lib/services/source/image',
      'lib/services/source/debug',
    ]) {
      for (final file in _dartFilesUnder(directory)) {
        for (final line in file.readAsLinesSync()) {
          if (line.trimLeft().startsWith('import ') &&
              line.contains('source_runtime_assembly.dart')) {
            violations.add('${file.path}: $line');
          }
        }
      }
    }
    expect(
      File('lib/services/hazuki_source_service.dart').existsSync(),
      isFalse,
    );
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('source collaborators do not use service part libraries', () {
    final violations = <String>[];
    for (final file in _dartFilesUnder('lib/services/source')) {
      final content = file.readAsStringSync();
      if (RegExp(r'^part of ', multiLine: true).hasMatch(content)) {
        violations.add('${file.path}: part of');
      }
      final isAdapter = file.path.replaceAll('\\', '/').contains('/adapters/');
      final isAssembly = file.path
          .replaceAll('\\', '/')
          .endsWith('source_runtime_assembly.dart');
      if (!isAdapter &&
          !isAssembly &&
          content.contains('source_runtime_assembly.dart')) {
        violations.add('${file.path}: source assembly import');
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('cloud sync participants do not use the global service locator', () {
    final violations = <String>[];
    for (final file in _dartFilesUnder('lib/services/cloud_sync')) {
      final content = file.readAsStringSync();
      if (content.contains('app/service_locator.dart') ||
          RegExp(r'\bsl<').hasMatch(content)) {
        violations.add(file.path);
      }
    }
    expect(violations, isEmpty, reason: 'cloud sync locator use: $violations');
  });

  test('shared and widget modules do not use the global service locator', () {
    final violations = <String>[];
    for (final directory in const ['lib/shared', 'lib/widgets']) {
      for (final file in _dartFilesUnder(directory)) {
        final content = file.readAsStringSync();
        if (content.contains('app/service_locator.dart') ||
            RegExp(r'\bsl<').hasMatch(content)) {
          violations.add(file.path);
        }
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('feature package imports do not form cycles', () {
    final root = Directory('lib/features');
    final graph = <String, Set<String>>{};
    final importPattern = RegExp(r'package:hazuki/features/([^/]+)/');

    for (final file in _dartFilesUnder(root.path)) {
      final relative = file.path.substring(root.path.length + 1);
      final from = relative.split(Platform.pathSeparator).first;
      final targets = graph.putIfAbsent(from, () => <String>{});
      for (final match in importPattern.allMatches(file.readAsStringSync())) {
        final to = match.group(1)!;
        if (to != from) targets.add(to);
      }
    }

    final visiting = <String>{};
    final visited = <String>{};
    final stack = <String>[];
    List<String>? cycle;

    bool visit(String node) {
      if (visiting.contains(node)) {
        final start = stack.indexOf(node);
        cycle = [...stack.sublist(start), node];
        return true;
      }
      if (visited.contains(node)) return false;
      visiting.add(node);
      stack.add(node);
      for (final next in graph[node] ?? const <String>{}) {
        if (visit(next)) return true;
      }
      stack.removeLast();
      visiting.remove(node);
      visited.add(node);
      return false;
    }

    for (final node in graph.keys) {
      if (visit(node)) break;
    }
    expect(cycle, isNull, reason: 'feature dependency cycle: $cycle');
  });

  test(
    'business features use injected builders for comments and favorites',
    () {
      final violations = <String>[];

      for (final file in _dartFilesUnder('lib/features/reader')) {
        final content = file.readAsStringSync();
        if (content.contains('features/comments/')) {
          violations.add('${file.path}: reader -> comments');
        }
      }

      for (final file in _dartFilesUnder('lib/features/comic_detail')) {
        final content = file.readAsStringSync();
        if (content.contains('features/comments/')) {
          violations.add('${file.path}: comic_detail -> comments');
        }
      }

      for (final file in _dartFilesUnder('lib/features/history')) {
        final content = file.readAsStringSync();
        if (content.contains('features/favorite/')) {
          violations.add('${file.path}: history -> favorite');
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Reader/Comic Detail must receive comments builders; History must '
            'receive favorite callbacks: $violations',
      );
    },
  );

  test(
    'reader feature receives app services through injected dependencies',
    () {
      final violations = <String>[];
      for (final file in _dartFilesUnder('lib/features/reader')) {
        final content = file.readAsStringSync();
        if (content.contains('app/service_locator.dart') ||
            RegExp(r'\bsl<').hasMatch(content)) {
          violations.add(file.path);
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Inject reader services from the app layer: $violations',
      );
    },
  );

  test('core business features receive app services through injection', () {
    final violations = <String>[];
    for (final feature in const [
      'comments',
      'comic_detail',
      'discover',
      'downloads',
      'favorite',
      'history',
      'search',
    ]) {
      for (final file in _dartFilesUnder('lib/features/$feature')) {
        final content = file.readAsStringSync();
        if (content.contains('app/service_locator.dart') ||
            RegExp(r'\bsl<').hasMatch(content)) {
          violations.add(file.path);
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Inject core business feature services: $violations',
    );
  });

  test('settings feature receives app services through injection', () {
    final violations = <String>[];
    for (final file in _dartFilesUnder('lib/features/settings')) {
      final content = file.readAsStringSync();
      if (content.contains('app/service_locator.dart') ||
          RegExp(r'\bsl<').hasMatch(content)) {
        violations.add(file.path);
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Inject settings feature services: $violations',
    );
  });

  test('home feature receives sibling features through app entrypoints', () {
    final violations = <String>[];
    final featureImportPattern = RegExp(r'package:hazuki/features/([^/]+)/');

    for (final file in _dartFilesUnder('lib/features/home')) {
      final content = file.readAsStringSync();
      for (final match in featureImportPattern.allMatches(content)) {
        final feature = match.group(1)!;
        if (feature != 'home') {
          violations.add('${file.path}: features/$feature');
        }
      }
      if (content.contains('app/service_locator.dart') ||
          RegExp(r'\bsl<').hasMatch(content)) {
        violations.add('${file.path}: service locator');
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Inject home feature entrypoints/services: $violations',
    );
  });

  test(
    'services do not resolve dependencies through the app service locator',
    () {
      final violations = _dartFilesUnder('lib/services')
          .where(
            (file) =>
                file.readAsStringSync().contains('app/service_locator.dart'),
          )
          .map((file) => file.path)
          .toList();

      expect(
        violations,
        isEmpty,
        reason: 'Inject service dependencies: $violations',
      );
    },
  );

  test('application and features do not depend on source implementations', () {
    final violations = <String>[];
    for (final directory in const ['lib/app', 'lib/features']) {
      for (final file in _dartFilesUnder(directory)) {
        final normalizedPath = file.path.replaceAll('\\', '/');
        if (normalizedPath.endsWith('lib/app/service_locator.dart') ||
            normalizedPath.endsWith(
              'lib/app/di/source_service_registrar.dart',
            )) {
          continue;
        }
        final content = file.readAsStringSync();
        if (content.contains(
              'services/source/runtime/source_runtime_assembly.dart',
            ) ||
            content.contains(
              'services/source/runtime/source_runtime_capability.dart',
            ) ||
            content.contains('sl<SourceRuntimeAssembly>') ||
            content.contains('.facade')) {
          violations.add(file.path);
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Depend on source gateway contracts: $violations',
    );
  });

  test('source gateways are backed by focused adapters', () {
    final forbidden =
        'HazukiSource'
        'Capabilities';
    final violations = <String>[];
    for (final root in const ['lib', 'test']) {
      for (final file in _dartFilesUnder(root)) {
        if (file.readAsStringSync().contains(forbidden)) {
          violations.add(file.path);
        }
      }
    }
    expect(
      violations,
      isEmpty,
      reason: 'Do not reintroduce the aggregate source adapter: $violations',
    );
  });

  test('source adapters do not depend on the runtime assembly', () {
    final violations = <String>[];
    for (final file in _dartFilesUnder('lib/services/source/adapters')) {
      final content = file.readAsStringSync();
      if (content.contains('source_runtime_assembly.dart') ||
          RegExp(r'\bSourceRuntimeAssembly\b').hasMatch(content) ||
          RegExp(r'\bdynamic\s+source\b').hasMatch(content)) {
        violations.add(file.path);
      }
    }
    expect(
      violations,
      isEmpty,
      reason:
          'Adapters must consume explicit runtime collaborators: $violations',
    );
  });

  test('service locator obtains source gateways from the gateway set', () {
    final content = File(
      'lib/app/di/source_service_registrar.dart',
    ).readAsStringSync();
    expect(content.contains('HazukiSource'), isFalse);
    expect(content.contains('.gateways.'), isTrue);
  });

  test('service locator delegates registration without service knowledge', () {
    final content = File('lib/app/service_locator.dart').readAsStringSync();
    expect(content.contains('services/'), isFalse);
    expect(content.contains('registerSourceServices(services)'), isTrue);
    expect(content.contains('registerApplicationServices(services)'), isTrue);
  });

  test('migrated source capabilities use explicit runtime dependencies', () {
    const paths = [
      'lib/services/source/explore_capability.dart',
      'lib/services/source/category/source_category_capability.dart',
      'lib/services/source/comic/source_comic_details_cache.dart',
      'lib/services/source/comic/source_comic_details_parser.dart',
      'lib/services/source/comic/comic_details_capability.dart',
      'lib/services/source/account/source_relogin_coordinator.dart',
      'lib/services/source/account/source_daily_check_in_capability.dart',
      'lib/services/source/account/source_login_operations.dart',
      'lib/services/source/account/source_login_script_factory.dart',
      'lib/services/source/account/source_login_side_data_operations.dart',
      'lib/services/source/account/picacg_login_profile_operations.dart',
      'lib/services/source/account/picacg_login_profile_parser.dart',
      'lib/services/source/account/picacg_profile_script_factory.dart',
      'lib/services/source/favorites/source_favorites_capability.dart',
      'lib/services/source/favorites/source_favorite_comics_loader.dart',
      'lib/services/source/favorites/source_favorites_policy.dart',
      'lib/services/source/favorites/source_favorites_response_parser.dart',
      'lib/services/source/favorites/source_favorite_folder_membership_probe.dart',
      'lib/services/source/favorites/source_favorites_script_factory.dart',
      'lib/services/source/image/source_image_preparation_capability.dart',
      'lib/services/source/image/image_download_scheduler.dart',
      'lib/services/source/image/image_disk_cache_store.dart',
      'lib/services/source/image/image_cache_policy.dart',
      'lib/services/source/image/source_image_network_downloader.dart',
      'lib/services/source/runtime/source_runtime_host.dart',
    ];
    final violations = <String>[];
    for (final path in paths) {
      final content = File(path).readAsStringSync();
      if (RegExp(r'^part of ', multiLine: true).hasMatch(content) ||
          content.contains('source_runtime_assembly.dart') ||
          content.contains('app/service_locator.dart')) {
        violations.add(path);
      }
    }
    expect(
      violations,
      isEmpty,
      reason:
          'Migrated source collaborators must have explicit dependencies: '
          '$violations',
    );
  });

  test('runtime initialization delegates source-script editing operations', () {
    final runtime = File(
      'lib/services/source/runtime/source_runtime_capability.dart',
    ).readAsStringSync();
    final operations = File(
      'lib/services/source/runtime/source_runtime_operations.dart',
    ).readAsStringSync();

    for (final method in const [
      'writeLocalActiveSource',
      'saveEditedActiveSource',
      'deleteLocalSourceFile',
      'hasCustomEditedSource',
    ]) {
      expect(
        RegExp('Future<[^>]+> $method\\(').hasMatch(runtime),
        isFalse,
        reason: '$method should belong to source-script operations',
      );
    }
    expect(operations.contains('_scripts.writeLocalActiveSource'), isTrue);
    expect(operations.contains('_scripts.saveEditedActiveSource'), isTrue);
  });

  test('runtime initialization delegates source update operations', () {
    final runtime = File(
      'lib/services/source/runtime/source_runtime_capability.dart',
    ).readAsStringSync();
    final operations = File(
      'lib/services/source/runtime/source_runtime_operations.dart',
    ).readAsStringSync();

    expect(runtime.contains('package:dio/dio.dart'), isFalse);
    expect(runtime.contains('checkActiveSourceVersionFromCloud()'), isFalse);
    expect(runtime.contains('downloadActiveSourceAndReload({'), isFalse);
    expect(operations.contains('_updates.checkActiveSourceVersion'), isTrue);
    expect(operations.contains('_updates.downloadActiveSource'), isTrue);
  });

  test('runtime composition delegates initialization workflows', () {
    final runtime = File(
      'lib/services/source/runtime/source_runtime_capability.dart',
    ).readAsStringSync();
    final operations = File(
      'lib/services/source/runtime/source_runtime_operations.dart',
    ).readAsStringSync();

    expect(runtime.contains('package:flutter_qjs/flutter_qjs.dart'), isFalse);
    expect(runtime.contains('rootBundle.loadString'), isFalse);
    expect(runtime.contains('Future<void> _initInternal'), isFalse);
    expect(runtime.contains('SourceRuntimeStep.loadingCache'), isFalse);
    expect(operations.contains('_initialization.init'), isTrue);
    expect(operations.contains('_initialization.ensureInitialized'), isTrue);
    expect(operations.contains('_initialization.prewarmInBackground'), isTrue);
    expect(
      operations.contains('_diagnostics.logRuntimeRetryRequested'),
      isTrue,
    );
  });

  test('runtime initialization delegates recovery workflows', () {
    final runtime = File(
      'lib/services/source/runtime/source_runtime_capability.dart',
    ).readAsStringSync();
    final operations = File(
      'lib/services/source/runtime/source_runtime_operations.dart',
    ).readAsStringSync();

    expect(runtime.contains('reloadFromLocalSourceFiles()'), isFalse);
    expect(runtime.contains('refreshSourceOnNetworkRecovery()'), isFalse);
    expect(operations.contains('_recovery.downloadSourceFile'), isTrue);
    expect(operations.contains('_recovery.reloadFromLocalSourceFiles'), isTrue);
    expect(
      operations.contains('_recovery.refreshSourceOnNetworkRecovery'),
      isTrue,
    );
  });

  test('account sessions delegate source-specific login workflows', () {
    final session = File(
      'lib/services/source/account/account_session_capability.dart',
    ).readAsStringSync();

    expect(session.contains("import 'dart:convert';"), isFalse);
    expect(session.contains('source_login.js'), isFalse);
    expect(session.contains('picacg_profile_avatar.js'), isFalse);
    expect(session.contains('_loginOperations.login('), isTrue);
    expect(session.contains('_loginOperations.loginWithFacade('), isTrue);
    expect(session.contains('_loginOperations.loadCurrentAvatarUrl()'), isTrue);
  });

  test('login orchestration delegates scripts and side data', () {
    final login = File(
      'lib/services/source/account/source_login_operations.dart',
    ).readAsStringSync();

    expect(login.contains("import 'dart:convert';"), isFalse);
    expect(login.contains('Network.post = async function'), isFalse);
    expect(login.contains('picacg_profile_avatar.js'), isFalse);
    expect(login.contains('_scriptFactory.build('), isTrue);
    expect(login.contains('_sideData.persistLoginSideData('), isTrue);
    expect(login.contains('_sideData.logPicacgLoginResponseTrace('), isTrue);
  });

  test('login side data delegates Picacg profile adaptation', () {
    final sideData = File(
      'lib/services/source/account/source_login_side_data_operations.dart',
    ).readAsStringSync();

    expect(sideData.contains('/users/profile'), isFalse);
    expect(sideData.contains('_decodeJwtPayload'), isFalse);
    expect(sideData.contains('_extractPicacgLoginToken'), isFalse);
    expect(sideData.contains('_picacg.persist('), isTrue);
    expect(sideData.contains('_picacg.logResponseTrace('), isTrue);
  });

  test('Picacg profile operations delegate scripts and parsing', () {
    final operations = File(
      'lib/services/source/account/picacg_login_profile_operations.dart',
    ).readAsStringSync();

    expect(operations.contains("import 'dart:convert';"), isFalse);
    expect(operations.contains('/users/profile'), isFalse);
    expect(operations.contains('normalizeSourceAvatarUrl'), isFalse);
    expect(operations.contains('._scriptFactory.build(token)'), isTrue);
    expect(operations.contains('.extractLoginToken(result)'), isTrue);
    expect(operations.contains('.parseProfileResult('), isTrue);
  });

  test('debug recorders write to the unified application log store', () {
    final structured = File(
      'lib/services/source/debug/debug_structured_log_recorder.dart',
    ).readAsStringSync();
    final networkRecorder = File(
      'lib/services/source/debug/debug_network_log_recorder.dart',
    ).readAsStringSync();

    expect(structured.contains('final AppLogStore store;'), isTrue);
    expect(networkRecorder.contains('final AppLogStore store;'), isTrue);
    expect(structured.contains('recentApplicationLogs'), isFalse);
    expect(networkRecorder.contains('recentNetworkLogs'), isFalse);
    expect(structured.contains('store.add('), isTrue);
    expect(networkRecorder.contains('store.add('), isTrue);
  });

  test('debug log capability delegates network retention policy', () {
    final capability = File(
      'lib/services/source/debug/debug_log_capability.dart',
    ).readAsStringSync();

    expect(capability.contains('_shouldSkipNetworkLogStorage'), isFalse);
    expect(capability.contains('_isImportantNetworkLogForStorage'), isFalse);
    expect(capability.contains('_shouldKeepDetailedNetworkResponse'), isFalse);
    expect(capability.contains('networkLogDedupedCount++'), isFalse);
    expect(capability.contains('_network.append('), isTrue);
  });

  test('debug log capability is a recorder facade', () {
    final capability = File(
      'lib/services/source/debug/debug_log_capability.dart',
    ).readAsStringSync();

    expect(capability.contains('void _pruneByAgeIfNeeded'), isFalse);
    expect(capability.contains('void _appendApplicationLog'), isFalse);
    expect(capability.contains('void _appendReaderLog'), isFalse);
    expect(capability.contains('_structured.addTyped('), isTrue);
    expect(capability.contains('_structured.addApplication('), isTrue);
    expect(capability.contains('_structured.addReader('), isTrue);
  });

  test('favorites capability delegates support and sort policy', () {
    final capability = File(
      'lib/services/source/favorites/source_favorites_capability.dart',
    ).readAsStringSync();

    expect(capability.contains('favorites_ordering'), isFalse);
    expect(capability.contains("'favoriteSort'"), isFalse);
    expect(capability.contains('singleFolderForSingleComic == true'), isFalse);
    expect(capability.contains('_policy.favoriteSortOrder'), isTrue);
    expect(capability.contains('_policy.setFavoriteSortOrder('), isTrue);
    expect(capability.contains('_policy.supportFavoriteToggle'), isTrue);
  });

  test('favorites capability delegates source response parsing', () {
    final capability = File(
      'lib/services/source/favorites/source_favorites_capability.dart',
    ).readAsStringSync();
    final comicsLoader = File(
      'lib/services/source/favorites/source_favorite_comics_loader.dart',
    ).readAsStringSync();

    expect(capability.contains('Map<String, dynamic>.from(resolved)'), isFalse);
    expect(capability.contains('final maxPageRaw ='), isFalse);
    expect(capability.contains('final folders = <FavoriteFolder>[]'), isFalse);
    expect(capability.contains('_parseExploreComics('), isFalse);
    expect(capability.contains('_responseParser.parseComicsPage('), isTrue);
    expect(capability.contains('_responseParser.parseFolders('), isTrue);
    expect(capability.contains('_responseParser.extractFolderIds('), isFalse);
    expect(comicsLoader.contains('_responseParser.parseComicsPage('), isTrue);
    expect(comicsLoader.contains('_responseParser.extractFolderIds('), isTrue);
  });

  test('favorites capability delegates folder membership probing', () {
    final capability = File(
      'lib/services/source/favorites/source_favorites_capability.dart',
    ).readAsStringSync();

    expect(capability.contains('const maxProbePages = 120'), isFalse);
    expect(capability.contains('while (page <= maxProbePages)'), isFalse);
    expect(capability.contains('_favoriteFolderContainsComic('), isFalse);
    expect(capability.contains('_membershipProbe.infer('), isTrue);
  });

  test('favorites capability delegates source script generation', () {
    final capability = File(
      'lib/services/source/favorites/source_favorites_capability.dart',
    ).readAsStringSync();

    expect(capability.contains("import 'dart:convert';"), isFalse);
    expect(capability.contains('favorites.loadComics('), isFalse);
    expect(capability.contains('favorites.loadNext('), isFalse);
    expect(capability.contains('favorites.loadFolders('), isFalse);
    expect(capability.contains('favorites.addOrDelFavorite('), isFalse);
    expect(capability.contains('_scriptFactory.loadComics('), isTrue);
    expect(capability.contains('_scriptFactory.loadFolders('), isTrue);
    expect(capability.contains('_scriptFactory.toggleFavorite('), isTrue);
  });

  test('favorites capability delegates comic page loading', () {
    final capability = File(
      'lib/services/source/favorites/source_favorites_capability.dart',
    ).readAsStringSync();

    expect(capability.contains('source_favorite_comics_all_null.js'), isFalse);
    expect(capability.contains('source_favorite_comics_all_0.js'), isFalse);
    expect(capability.contains('source_favorite_next.js'), isFalse);
    expect(capability.contains('_comicsLoader.load('), isTrue);
  });

  test('comic details capability delegates payload parsing', () {
    final capability = File(
      'lib/services/source/comic/comic_details_capability.dart',
    ).readAsStringSync();

    expect(capability.contains('_extractComicDetailsChapters'), isFalse);
    expect(capability.contains('_extractComicDetailsTags'), isFalse);
    expect(capability.contains('_extractComicDetailsRecommendations'), isFalse);
    expect(capability.contains('hazukiDefaultChapterTitleToken'), isFalse);
    expect(capability.contains('_parser.parse('), isTrue);
  });

  test('image cache delegates download concurrency scheduling', () {
    final capability = File(
      'lib/services/source/image/image_cache_capability.dart',
    ).readAsStringSync();

    expect(capability.contains("import 'dart:async';"), isFalse);
    expect(capability.contains("import 'dart:collection';"), isFalse);
    expect(capability.contains('_acquireSlot('), isFalse);
    expect(capability.contains('_releaseSlot('), isFalse);
    expect(capability.contains('_promoteWaitingDownload('), isFalse);
    expect(capability.contains('_downloadScheduler.schedule('), isTrue);
    expect(capability.contains('_downloadScheduler.promote('), isTrue);
  });

  test('image cache delegates disk storage and maintenance', () {
    final capability = File(
      'lib/services/source/image/image_cache_capability.dart',
    ).readAsStringSync();

    expect(capability.contains('package:crypto/crypto.dart'), isFalse);
    expect(
      capability.contains('package:path_provider/path_provider.dart'),
      isFalse,
    );
    expect(capability.contains('File('), isFalse);
    expect(capability.contains('_cacheFileFor('), isFalse);
    expect(capability.contains('_trimToOverflow('), isFalse);
    expect(capability.contains('_cleanByAge('), isFalse);
    expect(capability.contains('_diskCache.read('), isTrue);
    expect(capability.contains('_diskCache.write('), isTrue);
    expect(capability.contains('_diskCache.computeSizeBytes('), isTrue);
    expect(capability.contains('_diskCache.clear('), isTrue);
  });

  test('image cache delegates configuration and cleanup policy', () {
    final capability = File(
      'lib/services/source/image/image_cache_capability.dart',
    ).readAsStringSync();

    expect(capability.contains('SourcePrefsKeys.cacheMaxBytes'), isFalse);
    expect(capability.contains('cacheLastAutoCleanAt'), isFalse);
    expect(capability.contains('_enforcePolicyInternal('), isFalse);
    expect(capability.contains('_enforcePolicyInFlight'), isFalse);
    expect(capability.contains('_policy.setMaxBytes('), isTrue);
    expect(capability.contains('_policy.setAutoCleanMode('), isTrue);
    expect(capability.contains('_policy.enforce('), isTrue);
  });

  test('image cache delegates source-aware network downloads', () {
    final capability = File(
      'lib/services/source/image/image_cache_capability.dart',
    ).readAsStringSync();

    expect(capability.contains("import 'dart:convert';"), isFalse);
    expect(capability.contains('source_on_image_load.js'), isFalse);
    expect(capability.contains('buildCookieHeader('), isFalse);
    expect(capability.contains("category: 'image_download'"), isFalse);
    expect(capability.contains('_downloadFromNetwork('), isFalse);
    expect(capability.contains('_networkDownloader.download('), isTrue);
  });
}

Iterable<File> _dartFilesUnder(String path) sync* {
  final directory = Directory(path);
  for (final entity in directory.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) yield entity;
  }
}
