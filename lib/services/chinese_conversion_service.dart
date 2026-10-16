import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hazuki/shared/preferences/hazuki_preference_keys.dart';

enum ChineseConversionMode {
  off,
  traditional,
  simplified;

  static ChineseConversionMode decode(String? value) =>
      values.firstWhere((mode) => mode.name == value, orElse: () => off);
}

final hazukiChineseConversion = ChineseConversionService();

/// Converts display text only. Source models and persisted content stay intact.
class ChineseConversionService extends ChangeNotifier {
  ChineseConversionService({AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final _dictionaries = <ChineseConversionMode, _ConversionDictionary>{};
  final _cache = <String, String>{};
  ChineseConversionMode _mode = ChineseConversionMode.off;

  ChineseConversionMode get mode => _mode;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = ChineseConversionMode.decode(
      prefs.getString(hazukiChineseConversionPreferenceKey),
    );
    await _prepare(mode);
    _apply(mode);
  }

  Future<void> setMode(ChineseConversionMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await _prepare(mode);
    final saved = await prefs.setString(
      hazukiChineseConversionPreferenceKey,
      mode.name,
    );
    if (!saved) throw StateError('Could not save Chinese conversion mode');
    _apply(mode);
  }

  Future<void> _prepare(ChineseConversionMode mode) async {
    if (mode != ChineseConversionMode.off && !_dictionaries.containsKey(mode)) {
      final prefix = mode == ChineseConversionMode.traditional ? 'ST' : 'TS';
      final texts = await Future.wait([
        _bundle.loadString('assets/data/opencc/${prefix}Characters.txt'),
        _bundle.loadString('assets/data/opencc/${prefix}Phrases.txt'),
      ]);
      _dictionaries[mode] = await compute(_ConversionDictionary.parse, texts);
    }
  }

  void _apply(ChineseConversionMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    _cache.clear();
    notifyListeners();
  }

  String convert(String text) {
    if (_mode == ChineseConversionMode.off || text.isEmpty) return text;
    final cached = _cache.remove(text);
    if (cached != null) {
      _cache[text] = cached;
      return cached;
    }
    final converted = _dictionaries[_mode]!.convert(text);
    // Bound both the entry count and individual entry size for long comments.
    if (text.length <= 4096) {
      if (_cache.length >= 512) _cache.remove(_cache.keys.first);
      _cache[text] = converted;
    }
    return converted;
  }
}

class _ConversionDictionary {
  _ConversionDictionary(this.replacements, this.lengthsByFirstCodeUnit);

  final Map<String, String> replacements;
  final Map<int, List<int>> lengthsByFirstCodeUnit;

  static _ConversionDictionary parse(List<String> texts) {
    final replacements = <String, String>{};
    final lengths = <int, Set<int>>{};
    for (final text in texts) {
      for (final line in text.split('\n')) {
        if (line.isEmpty || line.startsWith('#')) continue;
        final parts = line.trimRight().split('\t');
        if (parts.length != 2) continue;
        final source = parts[0];
        if (source.isEmpty) continue;
        // OpenCC lists the preferred form first when there are alternatives.
        replacements[source] = parts[1].split(' ').first;
        lengths.putIfAbsent(source.codeUnitAt(0), () => {}).add(source.length);
      }
    }
    return _ConversionDictionary(replacements, {
      for (final entry in lengths.entries)
        entry.key: entry.value.toList()..sort((a, b) => b.compareTo(a)),
    });
  }

  String convert(String text) {
    final result = StringBuffer();
    var index = 0;
    while (index < text.length) {
      String? replacement;
      var matchedLength = 1;
      for (final length
          in lengthsByFirstCodeUnit[text.codeUnitAt(index)] ?? const <int>[]) {
        if (index + length > text.length) continue;
        replacement = replacements[text.substring(index, index + length)];
        if (replacement != null) {
          matchedLength = length;
          break;
        }
      }
      result.write(replacement ?? text.substring(index, index + 1));
      index += matchedLength;
    }
    return result.toString();
  }
}
