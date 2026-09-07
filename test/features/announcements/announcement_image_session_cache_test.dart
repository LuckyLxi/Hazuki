import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:hazuki/features/announcements/support/announcement_image_session_cache.dart';

void main() {
  test('reuses downloaded bytes for the current process session', () async {
    var downloadCount = 0;
    final cache = AnnouncementImageSessionCache(
      download: (url) async {
        downloadCount++;
        return Uint8List.fromList([1, 2, 3]);
      },
    );

    final first = await cache.load('https://example.com/image.jpg');
    final second = await cache.load('https://example.com/image.jpg');

    expect(first, same(second));
    expect(downloadCount, 1);
  });

  test('removes failed downloads so a later load can retry', () async {
    var downloadCount = 0;
    final cache = AnnouncementImageSessionCache(
      download: (url) async {
        downloadCount++;
        if (downloadCount == 1) {
          throw StateError('failed');
        }
        return Uint8List.fromList([1]);
      },
    );

    await expectLater(
      cache.load('https://example.com/image.jpg'),
      throwsStateError,
    );
    expect(await cache.load('https://example.com/image.jpg'), [1]);
    expect(downloadCount, 2);
  });
}
