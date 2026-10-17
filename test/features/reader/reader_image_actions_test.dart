import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/reader/support/reader_image_actions_service.dart';
import 'package:hazuki/features/reader/support/reader_save_image_controller.dart';
import 'package:hazuki/features/reader/view/reader_image_actions_sheet.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:mocktail/mocktail.dart';

class _Source extends Mock implements SourceReaderGateway {}

class _ImageActions extends Mock implements ReaderImageActionsService {}

void main() {
  const url = 'https://example.com/page.jpg';
  final bytes = Uint8List.fromList([1, 2, 3]);
  late _Source source;
  late _ImageActions media;
  late ReaderSaveImageController controller;
  var mounted = true;

  setUpAll(() => registerFallbackValue(Uint8List(0)));

  Future<void> pumpReader(
    WidgetTester tester, {
    Brightness brightness = Brightness.dark,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          brightness: brightness,
          colorSchemeSeed: Colors.purple,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              controller = ReaderSaveImageController(
                context: () => context,
                resolveReaderTheme: Theme.of,
                sourceReader: source,
                isMounted: () => mounted,
                logEvent:
                    (_, {level = 'info', source = 'reader_ui', content}) {},
                logPayload: ([extra]) => extra ?? {},
                comicId: 'comic',
                epId: 'chapter',
                sourceKey: 'source',
                imageActions: media,
              );
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
  }

  Future<void> finish(WidgetTester tester) async {
    // Let the existing transient prompt finish its timer and exit animation.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  setUp(() {
    mounted = true;
    source = _Source();
    media = _ImageActions();
    when(() => source.isLocalImagePath(any())).thenReturn(false);
    when(
      () => source.prepareChapterImageData(
        url,
        comicId: 'comic',
        epId: 'chapter',
        sourceKey: 'source',
      ),
    ).thenAnswer(
      (_) async => PreparedChapterImageData(
        bytes: bytes,
        extension: 'png',
        wasProcessed: true,
      ),
    );
    when(() => media.shareImage(bytes, 'png')).thenAnswer((_) async {});
    when(() => media.copyImage(bytes, 'png')).thenAnswer((_) async {});
    when(
      () => media.saveImage(bytes, 'png', 'page.png'),
    ).thenAnswer((_) async => 'content://gallery/page.png');
  });

  for (final action in [ReaderImageAction.copy, ReaderImageAction.save]) {
    testWidgets('Windows hides sharing and supports ${action.name}', (
      tester,
    ) async {
      await pumpReader(tester);
      final pending = controller.showSaveImageDialog(url);
      await tester.pumpAndSettle();
      expect(find.text('分享'), findsNothing);
      expect(find.text('复制图片'), findsOneWidget);
      expect(find.text('保存图片'), findsOneWidget);
      expect(find.byType(Divider), findsOneWidget);

      await tester.tap(
        find.text(action == ReaderImageAction.copy ? '复制图片' : '保存图片'),
      );
      await tester.pumpAndSettle();
      await pending;
      if (action == ReaderImageAction.copy) {
        verify(() => media.copyImage(bytes, 'png')).called(1);
      } else {
        verify(() => media.saveImage(bytes, 'png', 'page.png')).called(1);
      }
      verifyNever(() => media.shareImage(any(), any()));
      await finish(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  }

  for (final action in ReaderImageAction.values) {
    final label = switch (action) {
      ReaderImageAction.share => '分享',
      ReaderImageAction.copy => '复制图片',
      ReaderImageAction.save => '保存图片',
    };
    testWidgets(
      '$label uses processed image bytes and the resulting extension',
      (tester) async {
        await pumpReader(tester);
        final pending = controller.showSaveImageDialog(url);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(ReaderImageActionsSheet), findsOneWidget);
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        await pending;
        verify(
          () => source.prepareChapterImageData(
            url,
            comicId: 'comic',
            epId: 'chapter',
            sourceKey: 'source',
          ),
        ).called(1);
        switch (action) {
          case ReaderImageAction.share:
            verify(() => media.shareImage(bytes, 'png')).called(1);
          case ReaderImageAction.copy:
            verify(() => media.copyImage(bytes, 'png')).called(1);
            expect(find.text('图片已复制'), findsOneWidget);
          case ReaderImageAction.save:
            verify(() => media.saveImage(bytes, 'png', 'page.png')).called(1);
            expect(find.text('已保存'), findsOneWidget);
        }
        verifyNoMoreInteractions(media);
        await finish(tester);
      },
    );
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      'sheet layout, cancellation and repeated presses: $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await pumpReader(tester, brightness: brightness);
        final pending = controller.showSaveImageDialog(url);
        await tester.pumpAndSettle();
        await controller.showSaveImageDialog(url);
        expect(find.byType(ReaderImageActionsSheet), findsOneWidget);
        final share = tester.getCenter(find.text('分享'));
        final copy = tester.getCenter(find.text('复制图片'));
        final save = tester.getCenter(find.text('保存图片'));
        final cancel = tester.getCenter(find.text('取消'));
        expect(share.dx, 200);
        expect(copy.dx, share.dx);
        expect(save.dx, share.dx);
        expect(share.dy, greaterThan(500));
        expect(copy.dy, greaterThan(share.dy));
        expect(save.dy, greaterThan(copy.dy));
        expect(cancel.dy - save.dy, greaterThan(save.dy - copy.dy));
        expect(find.byType(Divider), findsNWidgets(2));
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        await pending;
        verifyNever(
          () => source.prepareChapterImageData(
            url,
            comicId: 'comic',
            epId: 'chapter',
            sourceKey: 'source',
          ),
        );
        verifyZeroInteractions(media);

        final reopened = controller.showSaveImageDialog(url);
        await tester.pumpAndSettle();
        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();
        await reopened;
        expect(find.byType(ReaderImageActionsSheet), findsNothing);
        verifyZeroInteractions(media);
      },
    );
  }

  testWidgets('copy failures are reported without a success prompt', (
    tester,
  ) async {
    when(
      () => media.copyImage(bytes, 'png'),
    ).thenThrow(StateError('clipboard unavailable'));
    await pumpReader(tester);
    final pending = controller.showSaveImageDialog(url);
    await tester.pumpAndSettle();
    await tester.tap(find.text('复制图片'));
    await tester.pumpAndSettle();
    await pending;
    expect(find.textContaining('复制图片失败'), findsOneWidget);
    expect(find.text('图片已复制'), findsNothing);
    await finish(tester);
  });

  testWidgets(
    'leaving the reader while preparing an image cancels the action',
    (tester) async {
      final prepared = Completer<PreparedChapterImageData>();
      when(
        () => source.prepareChapterImageData(
          url,
          comicId: 'comic',
          epId: 'chapter',
          sourceKey: 'source',
        ),
      ).thenAnswer((_) => prepared.future);
      await pumpReader(tester);
      final pending = controller.showSaveImageDialog(url);
      await tester.pumpAndSettle();
      await tester.tap(find.text('分享'));
      await tester.pumpAndSettle();
      mounted = false;
      prepared.complete(
        PreparedChapterImageData(
          bytes: bytes,
          extension: 'png',
          wasProcessed: true,
        ),
      );
      await tester.pumpAndSettle();
      await pending;
      verifyZeroInteractions(media);
    },
  );

  testWidgets('offline images are copied from the local file', (tester) async {
    late Directory directory;
    late File file;
    await tester.runAsync(() async {
      directory = await Directory.systemTemp.createTemp('hazuki-image-test-');
      file = File('${directory.path}/page.png');
      await file.writeAsBytes(bytes);
    });
    addTearDown(() => directory.delete(recursive: true));
    when(() => source.isLocalImagePath(file.path)).thenReturn(true);
    when(() => source.normalizeLocalImagePath(file.path)).thenReturn(file.path);
    when(() => media.copyImage(any(), 'png')).thenAnswer((_) async {});
    await pumpReader(tester);
    late Future<void> pending;
    await tester.runAsync(() async {
      pending = controller.showSaveImageDialog(file.path);
    });
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('复制图片'));
      await pending;
    });
    await tester.pumpAndSettle();
    final copied = verify(
      () => media.copyImage(captureAny(), 'png'),
    ).captured.single;
    expect(copied, bytes);
    verifyNever(
      () => source.prepareChapterImageData(
        any(),
        comicId: any(named: 'comicId'),
        epId: any(named: 'epId'),
        sourceKey: 'source',
      ),
    );
    await finish(tester);
  });
}
