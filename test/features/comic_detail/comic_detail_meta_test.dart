import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hazuki/features/comic_detail/view/comic_detail_meta.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';

void main() {
  testWidgets('detail authors and tags use category-aware tag callback', (
    tester,
  ) async {
    final pressedValues = <String>[];

    const details = ComicDetailsData(
      id: '123',
      title: 'Hazuki',
      subTitle: '',
      cover: '',
      description: '',
      updateTime: '',
      likesCount: '',
      chapters: <String, String>{},
      tags: <String, List<String>>{
        'author': <String>['Artist'],
        'tags': <String>['Action'],
        'views': <String>['10'],
      },
      recommend: <ExploreComic>[],
      isFavorite: false,
      subId: '',
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ComicDetailMetaSection(
            details: details,
            onCopyId: (_) {},
            onTagValuePressed: pressedValues.add,
            onMetaValueLongPress: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Artist'));
    await tester.tap(find.text('Action'));

    expect(pressedValues, <String>['Artist', 'Action']);
  });
}
