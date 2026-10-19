import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/home/view/home_profile_avatar.dart';
import 'package:hazuki/services/source/gateways/source_image_gateways.dart';
import 'package:hazuki/widgets/widgets.dart';

void main() {
  setUp(clearHazukiWidgetImageMemoryForTesting);
  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );
  }

  testWidgets('shows guest avatar when not loading and avatar url is empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const HomeProfileAvatar(avatarUrl: '', loading: false, size: 48)),
    );

    expect(find.byIcon(Icons.person_outline), findsOneWidget);
    expect(find.byType(HazukiShimmerLoading), findsNothing);
  });

  testWidgets('shows loading placeholder while profile is loading', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const HomeProfileAvatar(avatarUrl: '', loading: true, size: 48)),
    );

    expect(find.byType(HazukiShimmerLoading), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsNothing);
  });

  for (final borderRadius in [null, BorderRadius.circular(16)]) {
    testWidgets('retries transient avatar failure with radius $borderRadius', (
      tester,
    ) async {
      final gateway = _Images(failures: 1);
      await tester.pumpWidget(
        SourceImageGatewayScope(
          gateway: gateway,
          child: wrap(
            HomeProfileAvatar(
              avatarUrl: 'https://example/avatar',
              loading: false,
              size: 48,
              borderRadius: borderRadius,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(gateway.downloads, 1);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(gateway.downloads, 2);
      await tester.runAsync(
        () => precacheImage(
          MemoryImage(gateway.bytes),
          tester.element(find.byType(HomeProfileAvatar)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(HazukiShimmerLoading), findsNothing);
    });
  }

  testWidgets('stops retrying after two additional attempts', (tester) async {
    final gateway = _Images(failures: 100);
    await tester.pumpWidget(
      SourceImageGatewayScope(
        gateway: gateway,
        child: wrap(
          const HomeProfileAvatar(
            avatarUrl: 'https://example/avatar',
            loading: false,
            size: 48,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    await tester.pump(const Duration(seconds: 30));
    expect(gateway.downloads, 3);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('disposal cancels a scheduled avatar retry', (tester) async {
    final gateway = _Images(failures: 1);
    await tester.pumpWidget(
      SourceImageGatewayScope(
        gateway: gateway,
        child: wrap(
          const HomeProfileAvatar(
            avatarUrl: 'https://example/avatar',
            loading: false,
            size: 48,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
    expect(gateway.downloads, 1);
  });
}

class _Images implements SourceImageGateway {
  _Images({required this.failures});

  final int failures;
  int downloads = 0;
  final bytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );

  @override
  String get activeSourceKey => 'source';

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
  }) async {
    if (++downloads <= failures) throw StateError('offline');
    return bytes;
  }
}
