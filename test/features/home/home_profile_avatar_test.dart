import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/home/view/home_profile_avatar.dart';
import 'package:hazuki/widgets/widgets.dart';

void main() {
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
}
