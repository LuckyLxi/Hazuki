import 'dart:convert';
import 'dart:typed_data';

Never invalidDialog() =>
    throw const FormatException('plugin_ui_invalid_options');

Map<String, dynamic> dialogMap(Object? value) =>
    value is Map && value.keys.every((key) => key is String)
    ? Map<String, dynamic>.from(value)
    : invalidDialog();

void _text(Object? value, {bool required = false}) {
  if (value == null && !required) return;
  if (value is String &&
      value.length <= 32768 &&
      utf8.encode(value).length <= 32768) {
    return;
  }
  if (value is Map &&
      value.isNotEmpty &&
      value.keys.every((key) => key is String) &&
      value.values.every(
        (v) =>
            v is String && v.length <= 32768 && utf8.encode(v).length <= 32768,
      )) {
    return;
  }
  invalidDialog();
}

Map<String, Object> parseDialogFieldErrors(
  Object? raw,
  SourceDialogModel model,
) {
  final errors = dialogMap(raw);
  final ids = model.allComponents
      .where((c) => c.interactive)
      .map((c) => c.id)
      .toSet();
  for (final entry in errors.entries) {
    if (!ids.contains(entry.key)) invalidDialog();
    if (entry.value != null) _text(entry.value, required: true);
  }
  if (utf8.encode(jsonEncode(errors)).length > 256 * 1024) invalidDialog();
  return {
    for (final entry in errors.entries)
      if (entry.value != null) entry.key: entry.value as Object,
  };
}

/// 插件提供的纯字符串（漫画标题、标签值等站点数据），不参与插件翻译。
String _plain(Object? value, {int max = 4096, bool allowEmpty = false}) {
  if (value is String &&
      (allowEmpty || value.trim().isNotEmpty) &&
      value.length <= max) {
    return value;
  }
  return invalidDialog();
}

List<Object?> _list(Object? value, {required int min, required int max}) {
  if (value is List && value.length >= min && value.length <= max) {
    return value;
  }
  return invalidDialog();
}

void _oneOf(Object? value, Set<String> allowed) {
  if (value != null && !allowed.contains(value)) invalidDialog();
}

bool _isHttpUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri != null &&
      const {'http', 'https'}.contains(uri.scheme) &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty;
}

const _valueActions = {'search', 'copy', 'none'};
const _textTones = {'normal', 'error', 'secondary'};

/// row 只承载展示和轻量交互，避免嵌套布局与大尺寸组件挤在一行。
const _rowChildTypes = {
  'text',
  'richText',
  'image',
  'button',
  'rating',
  'tags',
  'progress',
};
final _iconName = RegExp(r'^[a-z0-9_]{1,40}$');

Uint8List _image(Object? raw) {
  Uint8List bytes;
  if (raw is Uint8List) {
    if (raw.length > 4 * 1024 * 1024) invalidDialog();
    bytes = Uint8List.fromList(raw);
  } else if (raw is List &&
      raw.length <= 4 * 1024 * 1024 &&
      raw.every((v) => v is int && v >= 0 && v <= 255)) {
    bytes = Uint8List.fromList(raw.cast<int>());
  } else if (raw is String &&
      raw.length <= 6 * 1024 * 1024 &&
      RegExp(r'^data:image/[^;,]+;base64,').hasMatch(raw)) {
    try {
      bytes = base64Decode(raw.substring(raw.indexOf(',') + 1));
    } on FormatException {
      return invalidDialog();
    }
  } else {
    return invalidDialog();
  }
  if (bytes.isEmpty || bytes.length > 4 * 1024 * 1024) invalidDialog();
  return bytes;
}

class SourceDialogComponent {
  SourceDialogComponent._(this.data, this.image, this.hintImage, this.children);
  factory SourceDialogComponent.parse(Object? raw, {bool nested = false}) {
    final data = dialogMap(raw);
    final type = data['type'];
    if (data['id'] is! String ||
        (data['id'] as String).isEmpty ||
        (data['id'] as String).length > 64 ||
        !const {
          'text',
          'image',
          'input',
          'select',
          'toggle',
          'clickImage',
          'progress',
          'divider',
          'rating',
          'row',
          'button',
          'comics',
          'tags',
          'info',
          'richText',
        }.contains(type) ||
        nested && !_rowChildTypes.contains(type)) {
      invalidDialog();
    }
    for (final field in ['text', 'label', 'placeholder', 'description']) {
      _text(data[field]);
    }
    for (final field in [
      'required',
      'obscure',
      'multiple',
      'notifyChange',
      'allowHalf',
      'readOnly',
      'enabled',
      'validate',
    ]) {
      if (data[field] != null && data[field] is! bool) invalidDialog();
    }
    final flex = data['flex'];
    if (flex != null && (flex is! int || flex < 0 || flex > 12)) {
      invalidDialog();
    }
    if (type == 'text') {
      _text(data['text'], required: true);
      _oneOf(data['tone'], _textTones);
    }
    if (type == 'image') {
      final height = data['height'];
      if (height != null &&
          (height is! num || !height.isFinite || height < 16 || height > 400)) {
        invalidDialog();
      }
      _oneOf(data['shape'], const {'rect', 'circle'});
    }
    if (type == 'rating') {
      final max = data['max'] ?? 5;
      if (max is! int || max < 1 || max > 10) invalidDialog();
      data['max'] = max;
      if (data['readOnly'] == true) {
        // 只读评分用于展示站点均分，允许任意小数。
        final value = data['initialValue'] ?? 0;
        if (value is! num || !value.isFinite || value < 0 || value > max) {
          invalidDialog();
        }
      }
    }
    if (type == 'button') {
      _text(data['text'], required: true);
      final icon = data['icon'];
      if (icon != null && (icon is! String || !_iconName.hasMatch(icon))) {
        invalidDialog();
      }
      _oneOf(data['style'], const {
        'filled',
        'tonal',
        'outlined',
        'text',
        'icon',
      });
      if (data['style'] == 'icon' && icon == null) invalidDialog();
    }
    if (type == 'comics') {
      _text(data['title']);
      _oneOf(data['layout'], const {'row', 'grid'});
      for (final raw in _list(data['items'], min: 1, max: 100)) {
        final item = dialogMap(raw);
        _plain(item['id'], max: 256);
        _plain(item['title']);
        for (final key in ['subtitle', 'cover']) {
          if (item[key] != null) _plain(item[key], allowEmpty: true);
        }
      }
    }
    if (type == 'tags') {
      _oneOf(data['action'], _valueActions);
      for (final value in _list(data['values'], min: 1, max: 100)) {
        _plain(value, max: 1024);
      }
    }
    if (type == 'info') {
      for (final raw in _list(data['rows'], min: 1, max: 32)) {
        final row = dialogMap(raw);
        _text(row['label'], required: true);
        _oneOf(row['action'], _valueActions);
        for (final value in _list(row['values'], min: 0, max: 100)) {
          _plain(value, max: 1024);
        }
      }
    }
    if (type == 'richText') {
      for (final raw in _list(data['spans'], min: 1, max: 200)) {
        final span = dialogMap(raw);
        _text(span['text'], required: true);
        for (final field in ['bold', 'italic']) {
          if (span[field] != null && span[field] is! bool) invalidDialog();
        }
        _oneOf(span['tone'], const {'normal', 'error', 'secondary', 'primary'});
        final link = span['link'];
        if (link != null && (link is! String || !_isHttpUrl(link))) {
          invalidDialog();
        }
      }
    }
    _oneOf(type == 'row' ? data['align'] : null, const {
      'start',
      'center',
      'end',
      'spaceBetween',
    });
    if (const {'input', 'select', 'toggle'}.contains(type)) {
      _text(data['label'], required: true);
    }
    if (type == 'input') {
      final length = data['maxLength'] ?? 4096;
      if (length is! int ||
          length < 1 ||
          length > 32768 ||
          data['keyboardType'] != null &&
              !const {'text', 'number'}.contains(data['keyboardType'])) {
        invalidDialog();
      }
      data['maxLength'] = length;
    }
    if (type == 'select') {
      final options = data['options'];
      if (options is! List || options.isEmpty || options.length > 100) {
        invalidDialog();
      }
      final seen = <String>{};
      for (final raw in options) {
        final option = dialogMap(raw);
        if (option['value'] is! String ||
            (option['value'] as String).isEmpty ||
            !seen.add(option['value'] as String)) {
          invalidDialog();
        }
        _text(option['label'], required: true);
      }
    }
    if (type == 'clickImage' && data['pointCount'] != null) {
      final count = data['pointCount'];
      if (count is! int || count < 1 || count > 32) invalidDialog();
    }
    if (type == 'progress' && data['value'] != null) {
      final value = data['value'];
      if (value is! num || !value.isFinite || value < 0 || value > 1) {
        invalidDialog();
      }
    }
    final component = SourceDialogComponent._(
      Map.unmodifiable(data),
      const {'image', 'clickImage'}.contains(type)
          ? _image(data['image'])
          : null,
      type == 'clickImage' && data['hintImage'] != null
          ? _image(data['hintImage'])
          : null,
      type == 'row'
          ? List.unmodifiable(
              _list(data['children'], min: 1, max: 8).map(
                (child) => SourceDialogComponent.parse(child, nested: true),
              ),
            )
          : const [],
    );
    if (component.interactive) component.validateValue(component.initialValue);
    return component;
  }
  final Map<String, dynamic> data;
  final Uint8List? image;
  final Uint8List? hintImage;

  /// row 的子组件；其余类型为空。
  final List<SourceDialogComponent> children;
  String get id => data['id'] as String;
  String get type => data['type'] as String;
  bool get interactive =>
      const {'input', 'select', 'toggle', 'clickImage'}.contains(type) ||
      type == 'rating' && data['readOnly'] != true;

  /// 自身及 row 内子组件，按显示顺序展开。
  Iterable<SourceDialogComponent> get flattened sync* {
    yield this;
    for (final child in children) {
      yield* child.flattened;
    }
  }

  Object get initialValue =>
      data['initialValue'] ??
      switch (type) {
        'toggle' => false,
        'rating' => 0,
        'clickImage' => <Object>[],
        'select' when data['multiple'] == true => <String>[],
        _ => '',
      };

  void validateValue(Object? value) {
    switch (type) {
      case 'input':
        if (value is! String || value.length > (data['maxLength'] as int)) {
          invalidDialog();
        }
      case 'toggle':
        if (value is! bool) invalidDialog();
      case 'rating':
        final max = data['max'] as int;
        // 可交互评分只接受整星，开启 allowHalf 时额外接受半星。
        final steps = data['allowHalf'] == true ? 2 : 1;
        if (value is! num ||
            !value.isFinite ||
            value < 0 ||
            value > max ||
            value * steps != (value * steps).roundToDouble()) {
          invalidDialog();
        }
      case 'select':
        final options = (data['options'] as List)
            .map((o) => (o as Map)['value'])
            .toSet();
        if (data['multiple'] == true) {
          if (value is! List ||
              value.toSet().length != value.length ||
              !value.every(options.contains)) {
            invalidDialog();
          }
        } else if (value is! String ||
            value.isNotEmpty && !options.contains(value)) {
          invalidDialog();
        }
      case 'clickImage':
        if (value is! List ||
            value.length > (data['pointCount'] as int? ?? 32)) {
          invalidDialog();
        }
        for (final point in value) {
          if (point is! Map ||
              ![
                'x',
                'y',
              ].every((key) => point[key] is int && (point[key] as int) >= 0)) {
            invalidDialog();
          }
        }
    }
  }
}

class SourceDialogModel {
  SourceDialogModel._(
    this.title,
    this.content,
    this.buttons,
    this.presentation,
    this.allComponents,
  );
  factory SourceDialogModel.parse(Object? raw) {
    final data = dialogMap(raw);
    _text(data['title'], required: true);
    final content = data['content'];
    final buttons = data['buttons'];
    // 内容区可放按钮后，纯展示窗口允许省略底部按钮。
    if (content is! List ||
        content.length > 64 ||
        buttons is! List ||
        buttons.length > 4) {
      invalidDialog();
    }
    final presentation = data['presentation'] ?? 'dialog';
    _oneOf(presentation, const {'dialog', 'sheet'});
    final components = content
        .map((raw) => SourceDialogComponent.parse(raw))
        .toList();
    final all = [for (final c in components) ...c.flattened];
    if (all.length > 64 ||
        all.map((c) => c.id).toSet().length != all.length ||
        all.fold<int>(
              0,
              (sum, c) =>
                  sum + (c.image?.length ?? 0) + (c.hintImage?.length ?? 0),
            ) >
            8 * 1024 * 1024) {
      invalidDialog();
    }
    final actions = buttons.map(dialogMap).toList();
    final ids = <String>{};
    var primary = 0;
    for (final button in actions) {
      if (button['id'] is! String ||
          (button['id'] as String).isEmpty ||
          (button['id'] as String).length > 64 ||
          !ids.add(button['id'] as String)) {
        invalidDialog();
      }
      _text(button['text'], required: true);
      if (button['role'] == 'primary') primary++;
      if (button['role'] != null &&
          !const {'primary', 'secondary'}.contains(button['role'])) {
        invalidDialog();
      }
      for (final key in ['enabled', 'validate']) {
        if (button[key] != null && button[key] is! bool) invalidDialog();
      }
    }
    if (primary > 1) invalidDialog();
    // 内容按钮与底部按钮共用 action 事件，id 冲突会让插件无法区分来源。
    if (all.any((c) => c.type == 'button' && ids.contains(c.id))) {
      invalidDialog();
    }
    final texts = [
      data['title'],
      for (final c in all) ...[
        for (final key in [
          'text',
          'label',
          'description',
          'placeholder',
          'title',
        ])
          c.data[key],
        if (c.type == 'select')
          for (final o in c.data['options'] as List) (o as Map)['label'],
        if (c.type == 'comics')
          for (final item in c.data['items'] as List) ...[
            (item as Map)['title'],
            item['subtitle'],
            item['cover'],
          ],
        if (c.type == 'tags') ...c.data['values'] as List,
        if (c.type == 'info')
          for (final row in c.data['rows'] as List) ...[
            (row as Map)['label'],
            ...row['values'] as List,
          ],
        if (c.type == 'richText')
          for (final span in c.data['spans'] as List) ...[
            (span as Map)['text'],
            span['link'],
          ],
      ],
      for (final b in actions) b['text'],
    ];
    if (utf8.encode(jsonEncode(texts)).length > 256 * 1024) invalidDialog();
    return SourceDialogModel._(
      data['title'] as Object,
      List.unmodifiable(components),
      List.unmodifiable(
        actions.map((b) => Map<String, dynamic>.unmodifiable(b)),
      ),
      presentation as String,
      List.unmodifiable(all),
    );
  }
  final Object title;
  final List<SourceDialogComponent> content;
  final List<Map<String, dynamic>> buttons;

  /// `dialog` 为居中弹窗，`sheet` 为底部面板；打开后不可通过 update 切换。
  final String presentation;

  /// 包含 row 子组件在内的全部组件，用于取值、校验和按 id 查找。
  final List<SourceDialogComponent> allComponents;
  Map<String, Object> get initialValues => {
    for (final c in allComponents.where((c) => c.interactive))
      c.id: c.initialValue,
  };
  SourceDialogModel patch(Map<String, dynamic> patch) =>
      SourceDialogModel.parse({
        'title': patch['title'] ?? title,
        'content': patch['content'] ?? content.map((c) => c.data).toList(),
        'buttons': patch['buttons'] ?? buttons,
        'presentation': presentation,
      });
}
