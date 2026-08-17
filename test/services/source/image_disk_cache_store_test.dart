import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/image/image_disk_cache_store.dart';

void main() {
  late Directory root;
  late Directory? cachedDirectory;
  late ImageDiskCacheStore store;
  late int resolveCount;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('hazuki_image_cache_test_');
    cachedDirectory = null;
    resolveCount = 0;
    store = ImageDiskCacheStore(
      getCachedDirectory: () => cachedDirectory,
      setCachedDirectory: (directory) => cachedDirectory = directory,
      resolveDirectory: () async {
        resolveCount++;
        return Directory('${root.path}/cache');
      },
    );
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('creates and reuses the resolved cache directory', () async {
    final first = await store.ensureDirectory();
    final second = await store.ensureDirectory();

    expect(await first.exists(), isTrue);
    expect(second.path, first.path);
    expect(resolveCount, 1);
  });

  test('keeps identical urls isolated by source key', () async {
    final firstBytes = Uint8List.fromList([1, 2, 3]);
    final secondBytes = Uint8List.fromList([4, 5]);

    expect(
      await store.write(
        'https://image.test/1.jpg',
        firstBytes,
        sourceKey: 'jm',
      ),
      isTrue,
    );
    expect(
      await store.write(
        'https://image.test/1.jpg',
        secondBytes,
        sourceKey: 'picacg',
      ),
      isTrue,
    );

    expect(
      await store.read('https://image.test/1.jpg', sourceKey: 'jm'),
      firstBytes,
    );
    expect(
      await store.read('https://image.test/1.jpg', sourceKey: 'picacg'),
      secondBytes,
    );
    expect(await store.computeSizeBytes(), 5);
    expect(
      await store.write(
        'https://image.test/1.jpg',
        firstBytes,
        sourceKey: 'jm',
      ),
      isFalse,
    );
  });

  test('cleans only files older than the retention threshold', () async {
    await store.write('old', Uint8List.fromList([1]), sourceKey: 'jm');
    final directory = await store.ensureDirectory();
    final oldFile =
        (await directory.list().where((entry) => entry is File).toList()).single
            as File;

    await store.write('fresh', Uint8List.fromList([2]), sourceKey: 'jm');
    final files = await directory
        .list()
        .where((entry) => entry is File)
        .toList();
    final freshFile = files.cast<File>().singleWhere(
      (file) => file.path != oldFile.path,
    );
    final now = DateTime(2026, 8, 17, 12);
    await oldFile.setLastModified(now.subtract(const Duration(days: 2)));
    await freshFile.setLastModified(now.subtract(const Duration(hours: 12)));

    await store.cleanByAge(const Duration(days: 1), now: now);

    expect(await oldFile.exists(), isFalse);
    expect(await freshFile.exists(), isTrue);
  });

  test(
    'trims oldest files to the configured target and supports eviction',
    () async {
      final directory = await store.ensureDirectory();
      final files = <File>[];
      for (var index = 0; index < 3; index++) {
        final before = (await directory.list().toList())
            .whereType<File>()
            .map((file) => file.path)
            .toSet();
        await store.write(
          'image-$index',
          Uint8List.fromList([index, index, index, index]),
          sourceKey: 'jm',
        );
        files.add(
          (await directory.list().toList()).whereType<File>().singleWhere(
            (file) => !before.contains(file.path),
          ),
        );
        await files.last.setLastModified(DateTime(2026, 8, 10 + index));
      }

      expect(
        await store.trimToOverflow(limitBytes: 10, targetRatio: 0.5),
        isTrue,
      );
      expect(await store.computeSizeBytes(), 4);
      expect(await store.read('image-0', sourceKey: 'jm'), isNull);
      expect(
        await store.read('image-2', sourceKey: 'jm'),
        Uint8List.fromList([2, 2, 2, 2]),
      );

      await store.evictEntries([' ', 'image-2'], sourceKey: 'jm');
      expect(await store.computeSizeBytes(), 0);

      await store.write('remaining', Uint8List.fromList([9]), sourceKey: 'jm');
      await store.clear();
      expect(await store.computeSizeBytes(), 0);
    },
  );
}
