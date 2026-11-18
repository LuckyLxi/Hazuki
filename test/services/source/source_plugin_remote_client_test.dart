import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/plugins/source_plugin_exception.dart';
import 'package:hazuki/services/source/plugins/source_plugin_remote_client.dart';
import 'package:hazuki/services/source/plugins/source_plugin_repository.dart';
import 'package:hazuki/services/preferences/software_update_source.dart';

void main() {
  final builtinPackage = Uri.parse(
    'https://raw.githubusercontent.com/LuckyLxi/Sources/main/fixture.js',
  );

  test('resolves the default branch through the injected download', () async {
    final requests = <Uri>[];
    final client = SourcePluginRemoteClient(
      download: (url) async {
        requests.add(url);
        return utf8.encode('{"default_branch":"dev"}');
      },
      loadUpdateSource: () => throw StateError('Unexpected preference read'),
    );

    final resolved = await client.resolveRepository(
      'https://github.com/author/sources.git',
      path: 'indexes/plugins.json',
    );
    expect(
      resolved.toString(),
      'https://raw.githubusercontent.com/author/sources/dev/indexes/plugins.json',
    );
    expect(requests, [Uri.https('api.github.com', '/repos/author/sources')]);
  });

  test('rejects invalid repository URLs before downloading', () async {
    final client = SourcePluginRemoteClient(
      download: (_) => throw StateError('Unexpected download'),
      loadUpdateSource: () => throw StateError('Unexpected preference read'),
    );

    for (final address in [
      'http://example.com/plugins.json',
      'https:///plugins.json',
      'https://user@example.com/plugins.json',
      'https://github.com/author',
    ]) {
      await expectLater(
        client.resolveRepository(address),
        throwsA(
          isA<SourcePluginException>().having(
            (error) => error.code,
            'code',
            'plugin_invalid_repository',
          ),
        ),
        reason: address,
      );
    }
  });

  test(
    'an unchanged package route is requested only once on failure',
    () async {
      final requests = <Uri>[];
      final failure = StateError('Package unavailable');
      final client = SourcePluginRemoteClient(
        download: (url) async {
          requests.add(url);
          throw failure;
        },
        loadUpdateSource: () async => SoftwareUpdateSource.github,
      );

      await expectLater(
        client.downloadPackage(sourcePluginsRepositoryUrl, builtinPackage),
        throwsA(same(failure)),
      );
      expect(requests, [builtinPackage]);
    },
  );

  test('an index download failure propagates without fallback', () async {
    final requests = <String>[];
    final failure = StateError('Index unavailable');
    final client = SourcePluginRemoteClient(
      download: (url) async {
        requests.add(url.toString());
        throw failure;
      },
      loadUpdateSource: () async => SoftwareUpdateSource.jsDelivr,
    );

    await expectLater(
      client.downloadIndex(Uri.parse(sourcePluginsRepositoryUrl)),
      throwsA(same(failure)),
    );
    expect(requests, [
      'https://cdn.jsdelivr.net/gh/LuckyLxi/Sources@main/plugins.json',
    ]);
  });

  test('third-party package downloads use the original URL', () async {
    final requests = <Uri>[];
    final bytes = utf8.encode('// script');
    final client = SourcePluginRemoteClient(
      download: (url) async {
        requests.add(url);
        return bytes;
      },
      loadUpdateSource: () => throw StateError('Unexpected preference read'),
    );

    expect(
      await client.downloadPackage(
        'https://example.com/plugins.json',
        builtinPackage,
      ),
      bytes,
    );
    expect(requests, [builtinPackage]);
  });
}
