import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/interaction/source_ui_scope.dart';
import 'package:hazuki/services/source/interaction/source_ui_service.dart';
import 'package:hazuki/services/source/models/source_script_execution.dart';
import 'package:hazuki/shared/source_interaction/source_plugin_dialog.dart';

Map<String, Object?> _options() => {
  'title': 'Gallery',
  'content': [
    {'id': 'average', 'type': 'rating', 'readOnly': true, 'initialValue': 4.32},
    {
      'id': 'score',
      'type': 'rating',
      'label': 'Your rating',
      'allowHalf': true,
    },
    {
      'id': 'header',
      'type': 'row',
      'children': [
        {'id': 'name', 'type': 'text', 'text': 'Uploader'},
        {
          'id': 'follow',
          'type': 'button',
          'text': 'Follow',
          'icon': 'add',
          'style': 'text',
        },
      ],
    },
    {
      'id': 'tags',
      'type': 'tags',
      'values': ['romance'],
    },
    {
      'id': 'info',
      'type': 'info',
      'rows': [
        {
          'label': 'Artist',
          'values': ['Alice'],
          'action': 'copy',
        },
      ],
    },
    {
      'id': 'notes',
      'type': 'richText',
      'spans': [
        {'text': 'Bold', 'bold': true},
        {'text': ' link', 'link': 'https://example.com'},
      ],
    },
    {
      'id': 'related',
      'type': 'comics',
      'items': [
        {'id': 'c1', 'title': 'Related comic', 'subtitle': 'Vol. 1'},
      ],
    },
  ],
  'buttons': <Object>[],
};

void main() {
  for (final sheet in [false, true]) {
    testWidgets('renders composite components (sheet: $sheet)', (tester) async {
      final service = SourceUiService();
      final shown = Completer<SourceDialogSession>();
      service.presenter = (dialog) async {
        dialog.markShown();
        shown.complete(dialog);
        await dialog.whenClosed;
      };
      // 插件操作结束会关闭窗口，测试期间保持操作进行中。
      final release = Completer<void>();
      final running = service.run(() async {
        final scope = SourceUiScope.current!..runtimeIds.add('engine');
        await service.handle(
          {'method': 'ui_open', 'options': _options()},
          SourceScriptExecution(
            taskId: 'task',
            pluginId: 'demo',
            method: 'action',
            uiScopeId: scope.id,
          ),
          'engine',
          'Demo',
        );
        await release.future;
      });
      await tester.pump();
      final dialog = await shown.future;
      final opened = <ExploreComic>[];
      final searched = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: Center(
              child: SourcePluginDialog(
                dialog: dialog,
                sheet: sheet,
                onOpenComic: opened.add,
                onSearch: searched.add,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Uploader'), findsOneWidget);
      expect(find.text('Follow'), findsOneWidget);
      expect(find.text('Related comic'), findsOneWidget);

      // 第二个评分组件可交互：点在第 3 颗星左半边得到 2.5 分。
      final stars = find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.slider == true,
      );
      final rect = tester.getRect(stars);
      await tester.tapAt(Offset(rect.left + 32 * 2 + 8, rect.center.dy));
      await tester.pump();
      expect(dialog.values['score'], 2.5);

      await tester.ensureVisible(find.text('romance'));
      await tester.tap(find.text('romance'));
      expect(searched, ['romance']);
      await tester.ensureVisible(find.text('Related comic'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Related comic'));
      expect(opened.single.id, 'c1');
      expect(opened.single.sourceKey, 'demo');

      final event = dialog.nextEvent();
      await tester.ensureVisible(find.text('Follow'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Follow'));
      expect((await event)['id'], 'follow');

      dialog.close('plugin');
      release.complete();
      await tester.pump();
      await running;
      service.detach();
    });
  }
}
