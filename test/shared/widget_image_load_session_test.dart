import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hazuki/services/source/gateways/source_image_gateways.dart';
import 'package:hazuki/shared/images/widget_image_load_session.dart';
import 'package:hazuki/shared/images/widget_image_memory.dart';

class _Gateway extends Mock implements SourceImageGateway {}

void main() {
  const url = 'https://example.test/image';
  late _Gateway gateway;
  late WidgetImageLoadSession session;
  setUp(() {
    clearHazukiWidgetImageMemoryForTesting();
    gateway = _Gateway();
    session = WidgetImageLoadSession();
  });

  WidgetImageLoadRequest begin({
    String source = 'jm',
    bool cover = true,
    bool keep = true,
  }) => session.begin(
    url: url,
    gateway: gateway,
    sourceKey: source,
    peekGatewayMemory: cover,
    keepInGatewayMemory: cover && keep,
    keepInWidgetMemory: keep,
  );

  test(
    'late completion from an old source cannot populate widget memory',
    () async {
      final completion = Completer<Uint8List>();
      when(
        () => gateway.downloadImageBytes(
          url,
          sourceKey: 'jm',
          keepInMemory: true,
        ),
      ).thenAnswer((_) => completion.future);
      final old = begin();
      final download = old.download();
      begin(source: 'other');
      completion.complete(Uint8List.fromList([1]));
      old.retain(await download);
      expect(old.matches(url: url, gateway: gateway, sourceKey: 'jm'), isFalse);
      expect(peekHazukiWidgetImageMemory(url, sourceKey: 'jm'), isNull);
    },
  );

  test(
    'invalidation rejects a request even if the same source and URL return',
    () {
      final old = begin();
      session.invalidate();
      final next = begin();
      expect(old.matches(url: url, gateway: gateway, sourceKey: 'jm'), isFalse);
      expect(next.matches(url: url, gateway: gateway, sourceKey: 'jm'), isTrue);
      expect(
        next.matches(url: url, gateway: _Gateway(), sourceKey: 'jm'),
        isFalse,
      );
      expect(
        next.matches(url: 'different', gateway: gateway, sourceKey: 'jm'),
        isFalse,
      );
    },
  );

  test(
    'cover can retain gateway memory while avatar skips the gateway peek',
    () {
      final bytes = Uint8List.fromList([2]);
      when(
        () => gateway.peekImageBytesFromMemory(url, sourceKey: 'jm'),
      ).thenReturn(bytes);
      expect(begin(cover: false).peek(), isNull);
      verifyNever(() => gateway.peekImageBytesFromMemory(url, sourceKey: 'jm'));
      expect(begin().peek(), bytes);
      expect(peekHazukiWidgetImageMemory(url, sourceKey: 'jm'), bytes);
      expect(begin(cover: false).peek(), bytes);
      verify(
        () => gateway.peekImageBytesFromMemory(url, sourceKey: 'jm'),
      ).called(1);
    },
  );

  test('cover with retention disabled leaves widget memory untouched', () {
    final bytes = Uint8List.fromList([3]);
    when(
      () => gateway.peekImageBytesFromMemory(url, sourceKey: 'jm'),
    ).thenReturn(bytes);
    final request = begin(keep: false);
    expect(request.peek(), bytes);
    request.retain(bytes);
    expect(peekHazukiWidgetImageMemory(url, sourceKey: 'jm'), isNull);
  });
}
