import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/widgets/cached_image_widgets.dart';

void main() {
  group('Hazuki widget image memory source scope', () {
    setUp(clearHazukiWidgetImageMemoryForTesting);

    test('keeps identical urls separate across source keys', () {
      const url = 'https://example.test/cover.jpg';
      final jmBytes = Uint8List.fromList([1, 2, 3]);
      final otherBytes = Uint8List.fromList([4, 5, 6]);

      putHazukiWidgetImageMemory(url, jmBytes, sourceKey: 'jm');
      putHazukiWidgetImageMemory(url, otherBytes, sourceKey: 'other');

      expect(peekHazukiWidgetImageMemory(url, sourceKey: 'jm'), jmBytes);
      expect(peekHazukiWidgetImageMemory(url, sourceKey: 'other'), otherBytes);
    });

    test('scoped reads can fall back to legacy unscoped bytes', () {
      const url = 'https://example.test/legacy-cover.jpg';
      final bytes = Uint8List.fromList([7, 8, 9]);

      putHazukiWidgetImageMemory(url, bytes);

      expect(peekHazukiWidgetImageMemory(url, sourceKey: 'jm'), bytes);
      expect(takeHazukiWidgetImageMemory(url, sourceKey: 'jm'), bytes);
      expect(peekHazukiWidgetImageMemory(url, sourceKey: 'jm'), bytes);
    });
  });
}
