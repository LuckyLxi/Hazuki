import 'package:re_editor/re_editor.dart';

typedef SourceCodeEditingController = CodeLineEditingController;

extension SourceCodeEditingControllerExtension on CodeLineEditingController {
  void loadText(String source) {
    text = source;
    selection = CodeLineSelection.collapsed(
      index: _lastLineIndex(source),
      offset: _lastLineLength(source),
    );
    clearComposing();
    clearHistory();
  }

  static int _lastLineIndex(String source) {
    if (source.isEmpty) {
      return 0;
    }
    return '\n'.allMatches(source).length;
  }

  static int _lastLineLength(String source) {
    if (source.isEmpty) {
      return 0;
    }
    final lastBreakIndex = source.lastIndexOf('\n');
    if (lastBreakIndex == -1) {
      return source.length;
    }
    return source.length - lastBreakIndex - 1;
  }
}
