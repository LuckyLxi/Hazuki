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
  final ids = model.content
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
  SourceDialogComponent._(this.data, this.image, this.hintImage);
  factory SourceDialogComponent.parse(Object? raw) {
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
        }.contains(type)) {
      invalidDialog();
    }
    for (final field in ['text', 'label', 'placeholder', 'description']) {
      _text(data[field]);
    }
    for (final field in ['required', 'obscure', 'multiple', 'notifyChange']) {
      if (data[field] != null && data[field] is! bool) invalidDialog();
    }
    if (type == 'text') {
      _text(data['text'], required: true);
      if (data['tone'] != null &&
          !const {'normal', 'error', 'secondary'}.contains(data['tone'])) {
        invalidDialog();
      }
    }
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
    );
    if (component.interactive) component.validateValue(component.initialValue);
    return component;
  }
  final Map<String, dynamic> data;
  final Uint8List? image;
  final Uint8List? hintImage;
  String get id => data['id'] as String;
  String get type => data['type'] as String;
  bool get interactive =>
      const {'input', 'select', 'toggle', 'clickImage'}.contains(type);
  Object get initialValue =>
      data['initialValue'] ??
      switch (type) {
        'toggle' => false,
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
  SourceDialogModel._(this.title, this.content, this.buttons);
  factory SourceDialogModel.parse(Object? raw) {
    final data = dialogMap(raw);
    _text(data['title'], required: true);
    final content = data['content'];
    final buttons = data['buttons'];
    if (content is! List ||
        content.length > 64 ||
        buttons is! List ||
        buttons.isEmpty ||
        buttons.length > 4) {
      invalidDialog();
    }
    final components = content.map(SourceDialogComponent.parse).toList();
    if (components.map((c) => c.id).toSet().length != components.length ||
        components.fold<int>(
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
    final texts = [
      data['title'],
      for (final c in components)
        for (final key in ['text', 'label', 'description', 'placeholder'])
          c.data[key],
      for (final c in components.where((c) => c.type == 'select'))
        for (final o in c.data['options'] as List) (o as Map)['label'],
      for (final b in actions) b['text'],
    ];
    if (utf8.encode(jsonEncode(texts)).length > 256 * 1024) invalidDialog();
    return SourceDialogModel._(
      data['title'] as Object,
      List.unmodifiable(components),
      List.unmodifiable(
        actions.map((b) => Map<String, dynamic>.unmodifiable(b)),
      ),
    );
  }
  final Object title;
  final List<SourceDialogComponent> content;
  final List<Map<String, dynamic>> buttons;
  Map<String, Object> get initialValues => {
    for (final c in content.where((c) => c.interactive)) c.id: c.initialValue,
  };
  SourceDialogModel patch(Map<String, dynamic> patch) =>
      SourceDialogModel.parse({
        'title': patch['title'] ?? title,
        'content': patch['content'] ?? content.map((c) => c.data).toList(),
        'buttons': patch['buttons'] ?? buttons,
      });
}
