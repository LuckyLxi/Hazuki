import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/app.dart';
import '../../l10n/app_localizations.dart';
import '../../models/hazuki_models.dart';

const searchLoadTimeout = Duration(seconds: 25);
const searchAppBarRevealOffset = 68.0;
const searchHistoryCollapsedMaxRows = 4;
const searchHistoryChipSpacing = 8.0;
const searchOrderKeys = <String>{
  'mr',
  'mv',
  'mv_m',
  'mv_w',
  'mv_t',
  'mp',
  'tf',
};

enum SearchEntryIntent {
  editFromEntry,
  submitFromEntry,
  historySelection,
  externalKeyword,
}

extension SearchEntryIntentExtension on SearchEntryIntent {
  bool get showKeyboardOnEnter => this == SearchEntryIntent.submitFromEntry;
}

typedef SearchPageLoader =
    Future<SearchComicsResult> Function(
      BuildContext context, {
      required String keyword,
      required int page,
      required String order,
    });

Map<String, String> searchOrderLabels(BuildContext context) {
  final strings = AppLocalizations.of(context)!;
  return {
    'mr': strings.searchOrderLatest,
    'mv': strings.searchOrderTotalRanking,
    'mv_m': strings.searchOrderMonthlyRanking,
    'mv_w': strings.searchOrderWeeklyRanking,
    'mv_t': strings.searchOrderDailyRanking,
    'mp': strings.searchOrderMostImages,
    'tf': strings.searchOrderMostLikes,
  };
}

Future<String> normalizeSubmittedKeyword(
  String rawKeyword, {
  TextEditingController? controller,
}) async {
  var keyword = rawKeyword.trim();
  if (keyword.isEmpty) {
    return '';
  }

  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(hazukiComicIdSearchEnhancePreferenceKey) == true) {
    final digitsOnly = keyword.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.length > 2 && digitsOnly != keyword) {
      keyword = digitsOnly;
      controller?.value = TextEditingValue(
        text: keyword,
        selection: TextSelection.collapsed(offset: keyword.length),
      );
    }
  }
  return keyword;
}

Future<void> addSearchHistory(String keyword) async {
  if (keyword.isEmpty) {
    return;
  }
  final prefs = await SharedPreferences.getInstance();
  final history = prefs.getStringList('search_history') ?? const <String>[];
  final newHistory = [keyword, ...history.where((e) => e != keyword)];
  if (newHistory.length > 50) {
    newHistory.removeRange(50, newHistory.length);
  }
  await prefs.setStringList('search_history', newHistory);
}

Widget buildAnimatedSearchActionButton({
  required bool showClearAction,
  required String clearKey,
  required String submitKey,
  required String clearTooltip,
  required String submitTooltip,
  required VoidCallback onClear,
  required VoidCallback onSubmit,
}) {
  return IconButton(
    tooltip: showClearAction ? clearTooltip : submitTooltip,
    onPressed: showClearAction ? onClear : onSubmit,
    icon: SizedBox(
      // 固定容器尺寸，防止 AnimatedSwitcher 过渡期间 Stack 大小变化
      // 导致键盘收起时触发 layout 重建而产生位置跳动
      width: 24,
      height: 24,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            alignment: Alignment.center,
            children: <Widget>[
              ...previousChildren,
              if (currentChild case final Widget child) child,
            ],
          );
        },
        transitionBuilder: (child, animation) {
          return ScaleTransition(
            scale: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
              reverseCurve: Curves.easeInCubic,
            ),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: Icon(
          showClearAction ? Icons.close : Icons.arrow_forward,
          key: ValueKey<String>(showClearAction ? clearKey : submitKey),
        ),
      ),
    ),
  );
}
