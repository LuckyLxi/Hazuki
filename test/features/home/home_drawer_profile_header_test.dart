import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/home/support/home_sidebar_models.dart';
import 'package:hazuki/features/home/view/home_drawer_content.dart';
import 'package:hazuki/features/home/view/home_profile_avatar.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/source/gateways/source_image_gateways.dart';
import 'package:hazuki/widgets/widgets.dart';

const _avatarUrl = 'https://example/avatar';

HomeSidebarProfileState _profile({
  bool loading = false,
  String name = 'reader',
  String avatarUrl = _avatarUrl,
}) => HomeSidebarProfileState(
  isLogged: true,
  profileLoading: loading,
  avatarUrl: avatarUrl,
  username: name,
  autoCheckInEnabled: false,
  showCheckInActions: false,
  checkInBusy: false,
  checkedInToday: false,
);

Widget _wrap(_Images images, HomeSidebarProfileState profile) =>
    SourceImageGatewayScope(
      gateway: images,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 304,
            child: HomeDrawerContent(
              profile: profile,
              actions: const HomeSidebarActions(),
              activeSourceKey: 'source',
            ),
          ),
        ),
      ),
    );

SnapshotController _snapshot(WidgetTester tester) =>
    tester.widget<SnapshotWidget>(find.byType(SnapshotWidget)).controller;

void _expectRevealing(WidgetTester tester) {
  expect(_snapshot(tester).allowSnapshotting, isFalse);
  final opacities = tester
      .renderObjectList<RenderAnimatedOpacity>(find.byType(AnimatedOpacity))
      .map((render) => render.opacity.value);
  // Both the avatar and the background must be between their first and last
  // visible frames, including when their bytes were already cached.
  expect(opacities.where((value) => value > 0 && value < 1), hasLength(2));
}

void main() {
  setUp(clearHazukiWidgetImageMemoryForTesting);

  testWidgets(
    'loading label transitions to username without remounting avatar',
    (tester) async {
      final images = _Images(cached: true);
      await tester.pumpWidget(_wrap(images, _profile(loading: true)));
      final avatarState = tester.state(find.byType(HomeProfileAvatar));
      // Read the localized loading label from the actual header.
      final label = tester
          .widget<Text>(
            find
                .descendant(
                  of: find.byType(AnimatedSwitcher),
                  matching: find.byType(Text),
                )
                .first,
          )
          .data!;
      await tester.pumpWidget(_wrap(images, _profile()));
      expect(tester.state(find.byType(HomeProfileAvatar)), same(avatarState));
      expect(find.text(label), findsOneWidget);
      expect(find.text('reader'), findsOneWidget);
      final fade = find
          .ancestor(
            of: find.text('reader'),
            matching: find.byType(FadeTransition),
          )
          .first;
      expect(tester.widget<FadeTransition>(fade).opacity.value, 0);
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.widget<FadeTransition>(fade).opacity.value,
        inExclusiveRange(0, 1),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text(label), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('cached avatar and background reveal before snapshotting', (
    tester,
  ) async {
    final images = _Images(cached: true);
    // Decode in advance to exercise the synchronous image-cache path too.
    await tester.pumpWidget(_wrap(images, _profile(loading: true)));
    await tester.runAsync(
      () => precacheImage(
        MemoryImage(images.bytes),
        tester.element(find.byType(HomeDrawerContent)),
      ),
    );
    await tester.pumpWidget(_wrap(images, _profile()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    _expectRevealing(tester);
    await tester.pumpAndSettle();
    expect(_snapshot(tester).allowSnapshotting, isTrue);
    expect(find.byType(HazukiShimmerLoading), findsNothing);
    expect(images.downloads, 0);

    // A label-only update must preserve the finished images and snapshot.
    final avatarState = tester.state(find.byType(HomeProfileAvatar));
    final snapshot = _snapshot(tester);
    await tester.pumpWidget(_wrap(images, _profile(name: 'another reader')));
    expect(tester.state(find.byType(HomeProfileAvatar)), same(avatarState));
    expect(_snapshot(tester), same(snapshot));
    expect(snapshot.allowSnapshotting, isTrue);
    expect(find.byType(AnimatedOpacity), findsNothing);
    await tester.pumpAndSettle();
  });

  testWidgets('downloaded images reveal after decoding and then cache', (
    tester,
  ) async {
    final images = _Images(cached: false);
    await tester.pumpWidget(_wrap(images, _profile()));
    await tester.pump();
    expect(_snapshot(tester).allowSnapshotting, isFalse);
    images.download.complete(images.bytes);
    await tester.pump();
    await tester.runAsync(
      () => precacheImage(
        MemoryImage(images.bytes),
        tester.element(find.byType(HomeDrawerContent)),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    _expectRevealing(tester);
    await tester.pumpAndSettle();
    expect(_snapshot(tester).allowSnapshotting, isTrue);
    expect(find.byType(HazukiShimmerLoading), findsNothing);
  });

  testWidgets('changing avatar URL loads and reveals the new image', (
    tester,
  ) async {
    final images = _Images(cached: true);
    await tester.pumpWidget(_wrap(images, _profile()));
    await tester.runAsync(
      () => precacheImage(
        MemoryImage(images.bytes),
        tester.element(find.byType(HomeDrawerContent)),
      ),
    );
    await tester.pumpAndSettle();
    // The new URL is absent from both memory caches.
    images.cached = false;
    await tester.pumpWidget(
      _wrap(images, _profile(avatarUrl: 'https://example/new-avatar')),
    );
    await tester.pump();
    expect(images.downloads, 2);
    expect(_snapshot(tester).allowSnapshotting, isFalse);
    images.download.complete(images.bytes);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    _expectRevealing(tester);
    await tester.pumpAndSettle();
    expect(_snapshot(tester).allowSnapshotting, isTrue);
    expect(find.byType(HazukiShimmerLoading), findsNothing);
  });

  testWidgets('repeated profile loads replay reveals and cancel stale work', (
    tester,
  ) async {
    final images = _Images(cached: true);
    await tester.pumpWidget(_wrap(images, _profile(loading: true)));
    await tester.runAsync(
      () => precacheImage(
        MemoryImage(images.bytes),
        tester.element(find.byType(HomeDrawerContent)),
      ),
    );
    for (var i = 0; i < 3; i++) {
      await tester.pumpWidget(_wrap(images, _profile()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      _expectRevealing(tester);
      await tester.pumpWidget(_wrap(images, _profile(loading: true)));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('long usernames remain constrained during the transition', (
    tester,
  ) async {
    final images = _Images(cached: true);
    await tester.pumpWidget(_wrap(images, _profile(loading: true)));
    await tester.pumpWidget(_wrap(images, _profile(name: 'reader ' * 30)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

class _Images implements SourceImageGateway {
  _Images({required this.cached});

  bool cached;
  final download = Completer<Uint8List>();
  int downloads = 0;
  final bytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );

  @override
  String get activeSourceKey => 'source';

  @override
  Uint8List? peekImageBytesFromMemory(String url, {String sourceKey = ''}) =>
      cached ? bytes : null;

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
    downloads++;
    return download.future;
  }
}
