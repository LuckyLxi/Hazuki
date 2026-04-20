import 'package:shared_preferences/shared_preferences.dart';

class SearchHistoryService {
  static const _key = 'search_history';
  static const _maxCount = 50;

  Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? const <String>[];
  }

  Future<void> add(String keyword) async {
    if (keyword.isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_key) ?? const <String>[];
    final next = [keyword, ...history.where((e) => e != keyword)];
    if (next.length > _maxCount) {
      next.removeRange(_maxCount, next.length);
    }
    await prefs.setStringList(_key, next);
  }

  Future<List<String>> remove(String keyword) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_key) ?? const <String>[];
    final next = current.where((e) => e != keyword).toList();
    await prefs.setStringList(_key, next);
    return next;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
