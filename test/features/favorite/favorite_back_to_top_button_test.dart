import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hazuki/features/favorite/view/favorite_page_content.dart';

void main() {
  testWidgets('uses the existing floating action button without liquid glass', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FavoriteBackToTopButton(visible: true, onPressed: _ignoreTap),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('favorite-back-to-top-fallback')),
      findsOneWidget,
    );
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}

void _ignoreTap() {}
