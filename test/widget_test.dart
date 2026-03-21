import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/main.dart';

void main() {
  testWidgets('Hazuki app renders basic navigation', (tester) async {
    await tester.pumpWidget(const HazukiApp());
    await tester.pump(const Duration(seconds: 21));
    await tester.pumpAndSettle();

    expect(find.text('Hazuki'), findsOneWidget);
    expect(find.text('发现'), findsOneWidget);
    expect(find.text('收藏'), findsOneWidget);
  });
}
