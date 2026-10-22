import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/widgets/cached_image_widgets.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/shared/comic_cover_prefetcher.dart';
import 'package:hazuki/shared/images/widget_image_load_session.dart';
import 'package:hazuki/shared/ui_flags.dart';

class _Gateway extends Fake implements SourceImageGateway {
  final origins = <String, List<SourceTaskOrigin>>{};
  final pending = <String, List<Completer<Uint8List>>>{};
  @override
  String get activeSourceKey => 'one';
  @override
  Uint8List? peekImageBytesFromMemory(String url, {String sourceKey = ''}) =>
      null;
  @override
  Future<Uint8List> downloadImageBytes(
    String url, {
    String comicId = '',
    String epId = '',
    bool keepInMemory = false,
    bool useDiskCache = true,
    bool priority = false,
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  }) {
    (origins[url] ??= []).add(taskOrigin!);
    final result = Completer<Uint8List>();
    (pending[url] ??= []).add(result);
    // Deliberately permit late completion to verify widget-cache guards.
    return result.future;
  }
}

void main() {
  late _Gateway gateway;
  late ComicCoverPrefetcher prefetch;
  setUp(() {
    gateway = _Gateway();
    hazukiNoImageModeNotifier.value = false;
    clearHazukiWidgetImageMemoryForTesting();
    prefetch = ComicCoverPrefetcher(imageGateway: gateway);
  });
  tearDown(() {
    prefetch.dispose();
    hazukiNoImageModeNotifier.value = false;
    clearHazukiWidgetImageMemoryForTesting();
  });
  final comics = [
    for (final id in ['a', 'b', 'c'])
      ExploreComic(
        id: id,
        title: id,
        subTitle: '',
        cover: 'https://fixture.test/$id',
        sourceKey: 'one',
      ),
  ];
  void range(int start, int end) => prefetch.prefetchRange(
    comics: comics,
    startIndex: start,
    endIndex: end,
    maxRequests: 3,
  );

  test('moving cover window releases only departed subscriptions', () async {
    range(0, 1);
    range(1, 2);
    expect(
      gateway.origins[comics[0].cover]!.single.cancellation!.reason,
      SourceTaskStopReason.superseded,
    );
    expect(
      gateway.origins[comics[1].cover]!.single.cancellation!.reason,
      isNull,
    );
    gateway.pending[comics[0].cover]!.single.complete(Uint8List.fromList([1]));
    await Future<void>.delayed(Duration.zero);
    expect(
      peekHazukiWidgetImageMemory(comics[0].cover, sourceKey: 'one'),
      isNull,
    );
  });

  test('no-image mode and disposal release admitted cover prefetch', () {
    range(0, 0);
    hazukiNoImageModeNotifier.value = true;
    expect(
      gateway.origins[comics[0].cover]!.single.cancellation!.reason,
      SourceTaskStopReason.superseded,
    );
    hazukiNoImageModeNotifier.value = false;
    range(1, 1);
    prefetch.dispose();
    expect(
      gateway.origins[comics[1].cover]!.single.cancellation!.reason,
      SourceTaskStopReason.ownerDisposed,
    );
  });

  test(
    'old prefetch completion cannot erase replacement subscription',
    () async {
      range(0, 0);
      range(1, 1);
      range(0, 0);
      gateway.pending[comics[0].cover]!.first.complete(Uint8List.fromList([1]));
      await Future<void>.delayed(Duration.zero);
      range(0, 0);
      expect(gateway.origins[comics[0].cover], hasLength(2));
      prefetch.dispose();
      expect(
        gateway.origins[comics[0].cover]!.last.cancellation!.reason,
        SourceTaskStopReason.ownerDisposed,
      );
    },
  );

  test('widget request replacement and disposal cancel separate signals', () {
    final session = WidgetImageLoadSession();
    WidgetImageLoadRequest begin(String url) => session.begin(
      url: url,
      gateway: gateway,
      sourceKey: 'one',
      peekGatewayMemory: false,
      keepInGatewayMemory: false,
      keepInWidgetMemory: false,
    );
    final first = begin('old');
    first.download();
    final next = begin('new');
    next.download();
    expect(
      gateway.origins['old']!.single.cancellation!.reason,
      SourceTaskStopReason.superseded,
    );
    expect(gateway.origins['new']!.single.cancellation!.reason, isNull);
    session.invalidate(SourceTaskStopReason.ownerDisposed);
    expect(
      gateway.origins['new']!.single.cancellation!.reason,
      SourceTaskStopReason.ownerDisposed,
    );
  });
  for (final circle in [false, true]) {
    testWidgets(
      'cached widget destruction releases subscription: circle=$circle',
      (tester) async {
        final image = circle
            ? HazukiCachedCircleAvatar(url: 'widget', imageGateway: gateway)
            : HazukiCachedImage(
                url: 'widget',
                imageGateway: gateway,
                useShimmerLoading: false,
              );
        await tester.pumpWidget(
          MaterialApp(
            home: Center(child: SizedBox(width: 60, height: 60, child: image)),
          ),
        );
        await tester.pump();
        expect(gateway.origins['widget'], hasLength(1));
        final signal = gateway.origins['widget']!.single.cancellation!;
        await tester.pumpWidget(const SizedBox());
        expect(signal.reason, SourceTaskStopReason.ownerDisposed);
      },
    );
  }
}
