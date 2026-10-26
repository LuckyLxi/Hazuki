import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/shared/navigation/route_transition_settled.dart';

class _Probe extends StatefulWidget {
  const _Probe();

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> with RouteTransitionSettledMixin {
  @override
  Widget build(BuildContext context) =>
      Text(routeTransitionSettled ? 'settled' : 'entering');
}

void main() {
  testWidgets('initial route is settled immediately', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: _Probe())));

    expect(find.text('settled'), findsOneWidget);
  });

  testWidgets('pushed route settles only after its entrance transition', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigatorKey, home: const SizedBox.shrink()),
    );

    // MaterialApp 带 HeroController，推入时会先经历一帧 offstage 预构建
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Scaffold(body: _Probe())),
    );
    await tester.pump();
    expect(find.text('entering', skipOffstage: false), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('entering'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('settled'), findsOneWidget);

    // 返回动画开始后保持已结束状态
    navigatorKey.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('settled'), findsOneWidget);
  });
}
