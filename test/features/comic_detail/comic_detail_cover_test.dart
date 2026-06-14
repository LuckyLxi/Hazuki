import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/comic_detail/view/comic_detail_cover.dart';

import '../../support/test_service_locator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await ensureTestServiceLocator();
  });

  testWidgets('cover preview uses the full page as its zoom canvas', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapPreview());

    final viewerFinder = find.byKey(
      const ValueKey<String>('comic_cover_viewer'),
    );
    final viewer = tester.widget<InteractiveViewer>(viewerFinder);
    final viewerSize = tester.getSize(viewerFinder);

    expect(viewer.clipBehavior, Clip.none);
    expect(viewer.boundaryMargin, EdgeInsets.zero);
    expect(viewerSize.width, greaterThan(700));
    expect(viewerSize.height, greaterThan(500));
  });

  testWidgets('cover preview stays fixed while it is not zoomed', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapPreview());

    final coverFinder = find.byIcon(Icons.broken_image_outlined);
    final originalCenter = tester.getCenter(coverFinder);

    await tester.drag(coverFinder, const Offset(140, 100));
    await tester.pumpAndSettle();

    final draggedCenter = tester.getCenter(coverFinder);
    expect(draggedCenter.dx, closeTo(originalCenter.dx, 0.01));
    expect(draggedCenter.dy, closeTo(originalCenter.dy, 0.01));
  });

  testWidgets('cover preview keeps its long press action', (tester) async {
    var longPressed = false;
    await tester.pumpWidget(
      _wrapPreview(onLongPress: () => longPressed = true),
    );

    await tester.longPress(find.byIcon(Icons.broken_image_outlined));

    expect(longPressed, isTrue);
  });
}

Widget _wrapPreview({VoidCallback? onLongPress}) {
  return MaterialApp(
    home: ComicCoverPreviewPage(
      imageUrl: '',
      sourceKey: '',
      heroTag: 'preview-hero',
      onLongPress: onLongPress ?? () {},
    ),
  );
}
