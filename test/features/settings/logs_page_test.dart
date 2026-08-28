import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/settings/view/debug/favorites_debug_page.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/source/source_capabilities.dart';

class _FakeDebugGateway implements SourceDebugGateway {
  final ChangeNotifier changes = ChangeNotifier();
  bool enabled = true;
  final logs = <Map<String, dynamic>>[];

  @override
  bool get softwareLogCaptureEnabled => enabled;
  @override
  Listenable get logChanges => changes;
  @override
  Future<bool> loadSoftwareLogCaptureEnabled() async => enabled;
  @override
  Future<void> setSoftwareLogCaptureEnabled(bool enabled) async {
    this.enabled = enabled;
  }

  @override
  void addApplicationLog({
    required String level,
    required String title,
    Object? content,
    String source = 'app',
  }) {}

  @override
  void addReaderLog({
    required String level,
    required String title,
    Object? content,
    String source = 'reader',
  }) {}

  @override
  Future<Map<String, dynamic>> collectAllDebugInfo() async => {
    'generatedAt': '2026-08-28T14:30:00.000',
    'platform': 'windows',
    'appVersion': '1.0.0',
    'logs': logs,
  };

  @override
  Future<Map<String, dynamic>> collectTypedDebugInfo(String type) =>
      collectAllDebugInfo();

  @override
  Future<void> clearCapturedLogs() async {
    logs.clear();
    changes.notifyListeners();
  }
}

void main() {
  testWidgets('shows one log list and opens complete details', (tester) async {
    final longText = 'complete-details-' * 100;
    final gateway = _FakeDebugGateway()
      ..logs.add({
        'id': '1',
        'time': '2026-08-28T14:29:21.000',
        'lastSeenAt': '2026-08-28T14:29:21.000',
        'level': 'error',
        'area': 'network',
        'source': 'js_http',
        'event': 'network_request',
        'title': 'Request failed',
        'data': {'responseBody': longText},
        'occurrences': 1,
      });

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LogsPage(debugGateway: gateway),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('All logs'), findsOneWidget);
    expect(find.text('Request failed'), findsOneWidget);
    expect(find.text('View details'), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);

    await tester.tap(find.text('View details'));
    await tester.pumpAndSettle();

    expect(find.text('Log details'), findsOneWidget);
    expect(find.textContaining(longText), findsOneWidget);

    await tester.tap(find.byIcon(Icons.copy_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Sensitive information'), findsNothing);
  });

  testWidgets('asks before copying a log with sensitive information', (
    tester,
  ) async {
    final gateway = _FakeDebugGateway()
      ..logs.add({
        'id': '1',
        'time': '2026-08-28T14:29:21.000',
        'level': 'warning',
        'title': 'Authentication failed',
        'data': {'Authorization': 'Bearer secret'},
      });

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LogsPage(debugGateway: gateway),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('View details'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.copy_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Sensitive information'), findsOneWidget);
    expect(
      find.text('Hide all sensitive information (recommended)'),
      findsOneWidget,
    );
  });

  testWidgets('search field stays unfocused after returning from details', (
    tester,
  ) async {
    final gateway = _FakeDebugGateway()
      ..logs.add({
        'id': '1',
        'time': '2026-08-28T14:29:21.000',
        'level': 'info',
        'title': 'Search result',
      });

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LogsPage(debugGateway: gateway),
      ),
    );
    await tester.pumpAndSettle();

    final searchField = find.byType(TextFormField);
    await tester.showKeyboard(searchField);
    var editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.focusNode.hasFocus, isTrue);

    await tester.tap(find.text('View details'));
    await tester.pumpAndSettle();
    expect(find.text('Log details'), findsOneWidget);

    Navigator.of(tester.element(find.text('Log details'))).pop();
    await tester.pumpAndSettle();

    editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.focusNode.hasFocus, isFalse);
  });

  testWidgets('log actions clear search focus before opening overlays', (
    tester,
  ) async {
    final gateway = _FakeDebugGateway()
      ..logs.add({
        'id': '1',
        'time': '2026-08-28T14:29:21.000',
        'level': 'warning',
        'title': 'Authentication failed',
        'data': {'Authorization': 'Bearer secret'},
      });

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LogsPage(debugGateway: gateway),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> focusSearch() async {
      await tester.showKeyboard(find.byType(TextFormField));
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.focusNode.hasFocus, isTrue);
    }

    void expectSearchUnfocused() {
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.focusNode.hasFocus, isFalse);
    }

    await focusSearch();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Sensitive information'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expectSearchUnfocused();

    await focusSearch();
    await tester.tap(find.byKey(const ValueKey<String>('logs-export')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Sensitive information'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expectSearchUnfocused();

    await focusSearch();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(16, 400));
    await tester.pumpAndSettle();
    expectSearchUnfocused();
  });
}
