import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/gateways/source_image_gateways.dart';
import 'package:hazuki/shared/navigation_tags.dart';
import 'package:hazuki/widgets/cached_image_widgets.dart';
import 'package:hazuki/widgets/source_image_gateway_scope.dart';

void main() {
  setUp(clearHazukiWidgetImageMemoryForTesting);

  testWidgets('reports a missing image gateway scope', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: HazukiCachedImage(url: '')),
    );

    expect(tester.takeException(), isNotNull);
  });

  testWidgets('supports explicit gateway injection without a scope', (
    tester,
  ) async {
    final gateway = _FakeSourceImageGateway(activeSourceKey: 'explicit');

    await tester.pumpWidget(
      MaterialApp(
        home: HazukiCachedImage(
          url: 'https://example.test/cover.png',
          imageGateway: gateway,
          useShimmerLoading: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(gateway.downloads, [('https://example.test/cover.png', 'explicit')]);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('circle avatar supports explicit gateway injection', (
    tester,
  ) async {
    final gateway = _FakeSourceImageGateway(activeSourceKey: 'avatar');

    await tester.pumpWidget(
      MaterialApp(
        home: HazukiCachedCircleAvatar(
          url: 'https://example.test/avatar.png',
          imageGateway: gateway,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(gateway.downloads, [('https://example.test/avatar.png', 'avatar')]);
  });

  testWidgets('reloads identical urls when the scoped source changes', (
    tester,
  ) async {
    const url = 'https://example.test/shared-cover.png';
    final firstGateway = _FakeSourceImageGateway(activeSourceKey: 'first');
    final secondGateway = _FakeSourceImageGateway(activeSourceKey: 'second');

    Widget buildApp(SourceImageGateway gateway) {
      return SourceImageGatewayScope(
        gateway: gateway,
        child: const MaterialApp(
          home: HazukiCachedImage(url: url, useShimmerLoading: false),
        ),
      );
    }

    await tester.pumpWidget(buildApp(firstGateway));
    await tester.pumpAndSettle();
    await tester.pumpWidget(buildApp(secondGateway));
    await tester.pumpAndSettle();

    expect(firstGateway.downloads, [(url, 'first')]);
    expect(secondGateway.downloads, [(url, 'second')]);
    expect(peekHazukiWidgetImageMemory(url, sourceKey: 'first'), isNotNull);
    expect(peekHazukiWidgetImageMemory(url, sourceKey: 'second'), isNotNull);
  });

  testWidgets('reloads when a singleton gateway changes active source', (
    tester,
  ) async {
    const url = 'https://example.test/singleton-cover.png';
    final gateway = _FakeSourceImageGateway(activeSourceKey: 'first');
    final sourceChanges = _SourceChangeNotifier();

    await tester.pumpWidget(
      SourceImageGatewayScope(
        gateway: gateway,
        sourceListenable: sourceChanges,
        child: const MaterialApp(
          home: HazukiCachedImage(url: url, useShimmerLoading: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    gateway.activeSourceKey = 'second';
    sourceChanges.notifySourceChanged();
    await tester.pumpAndSettle();

    expect(gateway.downloads, [(url, 'first'), (url, 'second')]);
  });

  testWidgets('ignores an older gateway response for the same url', (
    tester,
  ) async {
    const url = 'https://example.test/racing-cover.png';
    final firstGateway = _ControlledSourceImageGateway(
      activeSourceKey: 'first',
    );
    final secondGateway = _ControlledSourceImageGateway(
      activeSourceKey: 'second',
    );

    Widget buildApp(SourceImageGateway gateway) {
      return SourceImageGatewayScope(
        gateway: gateway,
        child: const MaterialApp(
          home: HazukiCachedImage(url: url, useShimmerLoading: false),
        ),
      );
    }

    await tester.pumpWidget(buildApp(firstGateway));
    await tester.pump();
    await tester.pumpWidget(buildApp(secondGateway));
    await tester.pump();

    secondGateway.completeDownload();
    await tester.pumpAndSettle();
    firstGateway.completeDownload();
    await tester.pumpAndSettle();

    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image as MemoryImage;
    expect(identical(provider.bytes, secondGateway.imageBytes), isTrue);
  });

  testWidgets('keeps circle avatar memory scoped to the active source', (
    tester,
  ) async {
    const url = 'https://example.test/shared-avatar.png';
    final gateway = _FakeSourceImageGateway(activeSourceKey: 'first');
    final sourceChanges = _SourceChangeNotifier();

    await tester.pumpWidget(
      SourceImageGatewayScope(
        gateway: gateway,
        sourceListenable: sourceChanges,
        child: const MaterialApp(home: HazukiCachedCircleAvatar(url: url)),
      ),
    );
    await tester.pumpAndSettle();

    gateway.activeSourceKey = 'second';
    sourceChanges.notifySourceChanged();
    await tester.pumpAndSettle();

    expect(gateway.downloads, [(url, 'first'), (url, 'second')]);
    expect(peekHazukiWidgetImageMemory(url, sourceKey: 'first'), isNotNull);
    expect(peekHazukiWidgetImageMemory(url, sourceKey: 'second'), isNotNull);
  });

  testWidgets('hero precache resolves the scoped gateway', (tester) async {
    final gateway = _FakeSourceImageGateway(activeSourceKey: 'hero');
    late BuildContext context;
    await tester.pumpWidget(
      SourceImageGatewayScope(
        gateway: gateway,
        child: MaterialApp(
          home: Builder(
            builder: (buildContext) {
              context = buildContext;
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    await precacheComicCoverHeroImages(
      context,
      url: 'https://example.test/hero.png',
      sourceKey: '',
    );

    expect(gateway.downloads, [('https://example.test/hero.png', 'hero')]);
  });
}

class _FakeSourceImageGateway implements SourceImageGateway {
  _FakeSourceImageGateway({required this.activeSourceKey});

  static final Uint8List _imageBytes = Uint8List.fromList(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    ),
  );

  @override
  String activeSourceKey;

  final List<(String, String)> downloads = <(String, String)>[];
  final Map<String, Uint8List> memory = <String, Uint8List>{};

  String _key(String url, String sourceKey) {
    return '${sourceKey.trim()}|${url.trim()}';
  }

  @override
  Uint8List? peekImageBytesFromMemory(String url, {String sourceKey = ''}) {
    return memory[_key(url, sourceKey)];
  }

  @override
  Future<Uint8List> downloadImageBytes(
    String url, {
    String comicId = '',
    String epId = '',
    bool keepInMemory = false,
    bool useDiskCache = true,
    bool priority = false,
    String sourceKey = '',
  }) async {
    final resolvedSourceKey = sourceKey.trim().isEmpty
        ? activeSourceKey
        : sourceKey.trim();
    downloads.add((url, resolvedSourceKey));
    if (keepInMemory) {
      memory[_key(url, resolvedSourceKey)] = _imageBytes;
    }
    return _imageBytes;
  }
}

class _SourceChangeNotifier extends ChangeNotifier {
  void notifySourceChanged() => notifyListeners();
}

class _ControlledSourceImageGateway implements SourceImageGateway {
  _ControlledSourceImageGateway({required this.activeSourceKey});

  @override
  final String activeSourceKey;

  final Completer<Uint8List> _download = Completer<Uint8List>();
  final Uint8List imageBytes = Uint8List.fromList(
    _FakeSourceImageGateway._imageBytes,
  );

  void completeDownload() => _download.complete(imageBytes);

  @override
  Uint8List? peekImageBytesFromMemory(String url, {String sourceKey = ''}) {
    return null;
  }

  @override
  Future<Uint8List> downloadImageBytes(
    String url, {
    String comicId = '',
    String epId = '',
    bool keepInMemory = false,
    bool useDiskCache = true,
    bool priority = false,
    String sourceKey = '',
  }) {
    return _download.future;
  }
}
