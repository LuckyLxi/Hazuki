import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/search/view/search_results_widgets.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/source/models/source_contract_models.dart';
import 'package:hazuki/widgets/widgets.dart';

void main() {
  Widget buildView({required bool loading}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SearchResultsStateView(
          searchKeyword: 'missing',
          searchLoading: loading,
          searchComics: const [],
          searchErrorMessage: null,
          sourceRuntimeState: const SourceRuntimeState.idle(),
          onRetry: () async {},
        ),
      ),
    );
  }

  testWidgets('empty result keeps the searching lens indicator state', (
    tester,
  ) async {
    await tester.pumpWidget(buildView(loading: true));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const ValueKey('search-loading')), findsOneWidget);
    final searchingState = tester.state(find.byType(HazukiSearchLensIndicator));

    await tester.pumpWidget(buildView(loading: false));
    await tester.pump(const Duration(milliseconds: 400));

    // 同一个 State 跨状态存活，放大镜才能从搜索动画衔接到空结果动画
    expect(find.byType(HazukiSearchLensIndicator), findsOneWidget);
    expect(
      tester.state(find.byType(HazukiSearchLensIndicator)),
      same(searchingState),
    );
    expect(find.byKey(const ValueKey('search-empty')), findsOneWidget);
    expect(find.byKey(const ValueKey('search-loading')), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });
}
