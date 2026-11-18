import 'source_plugin_exception.dart';

/// 插件在详情页声明的自定义标签页，排在宿主内置标签页之后。
class SourceDetailTab {
  const SourceDetailTab({required this.id, required this.title});

  static const maxCount = 8;

  final String id;

  /// 字符串或多语言对象，展示时经 `localizeSourcePluginText` 解析。
  final Object title;

  static List<SourceDetailTab> parseList(Object? value) {
    if (value == null) return const [];
    Never invalid() =>
        throw const SourcePluginException('plugin_invalid_detail_tabs');
    if (value is! List || value.length > maxCount) invalid();
    final seen = <String>{};
    return List.unmodifiable(
      value.map((item) {
        if (item is! Map) invalid();
        final id = item['id'];
        final title = item['title'];
        if (id is! String ||
            !RegExp(r'^[A-Za-z0-9_.-]{1,64}$').hasMatch(id) ||
            !_isText(title) ||
            !seen.add(id)) {
          invalid();
        }
        return SourceDetailTab(id: id, title: title as Object);
      }),
    );
  }

  static List<SourceDetailTab> forPresentation(
    Map<String, dynamic> presentation,
  ) => parseList(presentation['detailTabs']);
}

bool _isText(Object? value) =>
    (value is String && value.trim().isNotEmpty) ||
    (value is Map &&
        value.isNotEmpty &&
        value.values.any((v) => v is String && v.trim().isNotEmpty) &&
        value.entries.every((e) => e.key is String && e.value is String));

/// 插件标签页的内容区块，由宿主按类型渲染。
sealed class SourceDetailTabBlock {
  const SourceDetailTabBlock({this.title = ''});

  static const maxBlocks = 100;
  static const maxImagesPerBlock = 300;

  final String title;

  /// 未知类型的区块直接跳过，让旧版宿主兼容插件后续新增的区块类型。
  static List<SourceDetailTabBlock> parseList(Object? value) {
    Never invalid() =>
        throw const SourcePluginException('plugin_invalid_detail_tab_content');
    if (value == null) return const [];
    if (value is! List || value.length > maxBlocks) invalid();
    final blocks = <SourceDetailTabBlock>[];
    for (final item in value) {
      if (item is! Map) invalid();
      final title = item['title'];
      if (title != null && title is! String) invalid();
      final normalizedTitle = (title as String?)?.trim() ?? '';
      switch (item['type']) {
        case 'text':
          final text = item['text'];
          if (text is! String) invalid();
          blocks.add(SourceDetailTextBlock(title: normalizedTitle, text: text));
        case 'images':
          final urls = item['urls'];
          if (urls is! List ||
              urls.length > maxImagesPerBlock ||
              urls.any((url) => url is! String || url.trim().isEmpty)) {
            invalid();
          }
          blocks.add(
            SourceDetailImagesBlock(
              title: normalizedTitle,
              urls: List.unmodifiable(
                urls.map((url) => (url as String).trim()),
              ),
            ),
          );
        default:
          continue;
      }
    }
    return List.unmodifiable(blocks);
  }
}

class SourceDetailTextBlock extends SourceDetailTabBlock {
  const SourceDetailTextBlock({super.title, required this.text});

  final String text;
}

class SourceDetailImagesBlock extends SourceDetailTabBlock {
  const SourceDetailImagesBlock({super.title, required this.urls});

  final List<String> urls;
}
