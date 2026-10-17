import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/discover/view/discover_section_page_widgets.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';

void main() {
  const dates = <CategoryRankingOption>[
    CategoryRankingOption(value: '2026-06-15', label: '2026-06-15'),
    CategoryRankingOption(value: '2026-06-22', label: '2026-06-22'),
  ];

  Widget wrap({required ValueChanged<String> onSelected}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: DiscoverSectionSortBar(
          sortOptions: dates,
          useDateMorphSelector: true,
          selectedSortValue: dates.first.value,
          onSelectSortOption: onSelected,
        ),
      ),
    );
  }

  testWidgets('weekly date selector morphs into a dialog and selects a date', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(wrap(onSelected: (value) => selected = value));

    expect(find.byType(ChoiceChip), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('weekly_date_launcher')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('weekly_date_launcher')),
    );
    await tester.pump(const Duration(milliseconds: 210));

    expect(
      find.byKey(const ValueKey<String>('weekly_date_morph_animation')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Opacity>(
            find.byKey(const ValueKey<String>('weekly_date_launcher_opacity')),
          )
          .opacity,
      0,
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text(dates.last.label).last);
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      tester
          .widget<Opacity>(
            find.byKey(const ValueKey<String>('weekly_date_launcher_opacity')),
          )
          .opacity,
      0,
    );

    await tester.pumpAndSettle();

    expect(selected, dates.last.value);
    expect(
      tester
          .widget<Opacity>(
            find.byKey(const ValueKey<String>('weekly_date_launcher_opacity')),
          )
          .opacity,
      1,
    );
  });

  testWidgets('dialog opens with the selected date already in view', (
    tester,
  ) async {
    final manyDates = List<CategoryRankingOption>.generate(
      30,
      (index) =>
          CategoryRankingOption(value: 'date-$index', label: 'Date $index'),
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DiscoverSectionSortBar(
            sortOptions: manyDates,
            useDateMorphSelector: true,
            selectedSortValue: manyDates[20].value,
            onSelectSortOption: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('weekly_date_launcher')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('weekly_date_selected_target')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('weekly_date_selected_target')),
        matching: find.text(manyDates[20].label),
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<ListView>(find.byType(ListView)).controller!.offset,
      greaterThan(0),
    );
  });

  testWidgets('regular sort bar uses a horizontally scrollable capsule', (
    tester,
  ) async {
    var selectedValue = dates.first.value;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: DiscoverSectionSortBar(
              sortOptions: dates,
              selectedSortValue: selectedValue,
              onSelectSortOption: (value) {
                setState(() => selectedValue = value);
              },
            ),
          ),
        ),
      ),
    );

    expect(find.byType(ChoiceChip), findsNothing);
    final capsule = find.byKey(
      const ValueKey<String>('discover_section_sort_group_0'),
    );
    expect(capsule, findsOneWidget);
    expect(
      find.descendant(
        of: capsule,
        matching: find.byType(SingleChildScrollView),
      ),
      findsOneWidget,
    );
    final material = tester.widget<Material>(capsule);
    expect(material.borderRadius, BorderRadius.circular(999));
    expect(
      find.ancestor(of: capsule, matching: find.byType(BackdropFilter)),
      findsOneWidget,
    );
    expect(material.color!.a, closeTo(0.72, 0.01));
    final indicator = find.byKey(
      const ValueKey<String>('discover_section_sort_indicator'),
    );
    final animatedIndicator = tester.widget<AnimatedPositioned>(indicator);
    expect(animatedIndicator.duration, const Duration(milliseconds: 260));
    expect(
      find.byKey(const ValueKey<String>('weekly_date_launcher')),
      findsNothing,
    );

    final initialX = tester.getTopLeft(indicator).dx;
    await tester.tap(find.text(dates.last.label));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final movingX = tester.getTopLeft(indicator).dx;
    await tester.pumpAndSettle();
    final settledX = tester.getTopLeft(indicator).dx;

    expect(selectedValue, dates.last.value);
    expect(movingX, greaterThan(initialX));
    expect(movingX, lessThan(settledX));
  });

  testWidgets('long sort labels stay complete at different text scales', (
    tester,
  ) async {
    const options = [
      CategoryRankingOption(value: 'all', label: '全部'),
      CategoryRankingOption(value: 'long', label: '这是一个比较长的筛选选项'),
      CategoryRankingOption(value: 'latest', label: 'Latest updated comics'),
    ];
    for (final scale in [1.0, 1.6]) {
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: SizedBox(
                width: 320,
                child: DiscoverSectionSortBar(
                  sortOptions: options,
                  selectedSortValue: options.first.value,
                  onSelectSortOption: (value) => selected = value,
                ),
              ),
            ),
          ),
        ),
      );

      for (final option in options) {
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(option.label),
        );
        expect(paragraph.didExceedMaxLines, isFalse);
      }
      await tester.ensureVisible(find.text(options.last.label));
      await tester.tap(find.text(options.last.label));
      expect(selected, options.last.value);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('sort widths update when labels change after being measured', (
    tester,
  ) async {
    final options = [
      const CategoryRankingOption(value: 'all', label: 'All'),
      const CategoryRankingOption(value: 'latest', label: 'Latest'),
    ];
    const longLabel = 'A much longer filter label after the source changes';
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Scaffold(
              body: SizedBox(
                width: 320,
                child: DiscoverSectionSortBar(
                  sortOptions: options,
                  selectedSortValue: 'all',
                  onSelectSortOption: (_) {},
                ),
              ),
            );
          },
        ),
      ),
    );
    update(() {
      options[1] = const CategoryRankingOption(
        value: 'latest',
        label: longLabel,
      );
    });
    await tester.pumpAndSettle();

    expect(
      tester
          .renderObject<RenderParagraph>(find.text(longLabel))
          .didExceedMaxLines,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('weekly page morphs the time group and keeps type chips', (
    tester,
  ) async {
    const types = <CategoryRankingOption>[
      CategoryRankingOption(value: 'manga', label: '日漫'),
      CategoryRankingOption(value: 'hanman', label: '韓漫'),
      CategoryRankingOption(value: 'another', label: '其他'),
    ];
    int? selectedGroup;
    String? selectedValue;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DiscoverSectionSortBar(
            sortOptions: dates,
            sortOptionGroups: const [dates, types],
            useDateMorphSelector: true,
            selectedSortValue: dates.first.value,
            selectedSortValues: const ['2026-06-15', 'manga'],
            onSelectSortOption: (_) {},
            onSelectSortOptionInGroup: (group, value) {
              selectedGroup = group;
              selectedValue = value;
            },
          ),
        ),
      ),
    );

    expect(find.byType(ChoiceChip), findsNothing);
    expect(
      find.byKey(
        const ValueKey<String>('discover_section_sort_option_1_another'),
      ),
      findsOneWidget,
    );
    expect(find.text(dates.first.label), findsOneWidget);

    await tester.tap(find.text(types.last.label));
    expect(selectedGroup, 1);
    expect(selectedValue, types.last.value);
  });

  testWidgets('previous and next issue buttons follow source date order', (
    tester,
  ) async {
    final issues = <CategoryRankingOption>[
      const CategoryRankingOption(value: 'latest', label: 'Latest'),
      const CategoryRankingOption(value: 'middle', label: 'Middle'),
      const CategoryRankingOption(value: 'oldest', label: 'Oldest'),
    ];
    String selectedValue = issues[1].value;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: Stack(
              children: [
                DiscoverSectionIssueNavigationButtons(
                  options: issues,
                  selectedValue: selectedValue,
                  onSelected: (value) {
                    setState(() => selectedValue = value);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('weekly_date_previous')),
    );
    await tester.pump();
    expect(selectedValue, 'latest');

    await tester.tap(find.byKey(const ValueKey<String>('weekly_date_next')));
    await tester.pump();
    expect(selectedValue, 'middle');
    await tester.tap(find.byKey(const ValueKey<String>('weekly_date_next')));
    await tester.pump();
    expect(selectedValue, 'oldest');

    final nextButton = tester.widget<FloatingActionButton>(
      find.byKey(const ValueKey<String>('weekly_date_next')),
    );
    expect(nextButton.onPressed, isNull);
    expect(tester.getSize(find.byType(FloatingActionButton).first).width, 56);
    expect(
      tester
          .getCenter(find.byKey(const ValueKey<String>('weekly_date_next')))
          .dx,
      greaterThan(700),
    );
    expect(
      tester
          .getCenter(find.byKey(const ValueKey<String>('weekly_date_next')))
          .dy,
      greaterThan(500),
    );
  });
}
