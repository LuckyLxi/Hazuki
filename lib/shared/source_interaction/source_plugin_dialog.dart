import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/services/source/interaction/source_dialog_model.dart';
import 'package:hazuki/services/source/interaction/source_ui_service.dart';
import 'package:hazuki/services/source/plugins/source_plugin_localization.dart';

import '../source_account/source_account_dialog_support.dart';
import '../source_account/source_login_dialog_controller.dart';
import 'captcha_image_point.dart';

class SourcePluginDialog extends StatefulWidget {
  const SourcePluginDialog({
    super.key,
    required this.dialog,
    this.embedded = false,
    this.onUserClose,
  });
  final SourceDialogSession dialog;
  final bool embedded;
  final VoidCallback? onUserClose;
  @override
  State<SourcePluginDialog> createState() => _SourcePluginDialogState();
}

class _SourcePluginDialogState extends State<SourcePluginDialog> {
  SourceDialogSession get dialog => widget.dialog;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !dialog.isClosed) dialog.markShown();
    });
  }

  String text(Object? value) => localizeSourcePluginText(
    value,
    Localizations.localeOf(context).toLanguageTag(),
    translation: dialog.translation,
  );

  void close() {
    dialog.close('user');
    widget.onUserClose?.call();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: dialog,
    builder: (context, _) {
      final strings = l10n(context);
      return IgnorePointer(
        ignoring: dialog.isClosed,
        child: SourceLoginStepContent(
          embedded: widget.embedded,
          backgroundColor: homeDialogBackgroundColor(context),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      text(dialog.model.title),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: close,
                    tooltip: strings.commonClose,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(
                dialog.sourceName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: 320,
              maxWidth: 320,
              maxHeight: MediaQuery.sizeOf(context).height * .55,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (dialog.busy) const LinearProgressIndicator(),
                  for (final component in dialog.model.content)
                    Padding(
                      key: ValueKey((component.id, component.type)),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: componentWidget(component),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            for (final b in dialog.model.buttons)
              if (b['role'] == 'primary')
                FilledButton(
                  onPressed: dialog.busy || b['enabled'] == false
                      ? null
                      : () => dialog.action(b['id'] as String),
                  child: Text(
                    text(b['text']),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else
                TextButton(
                  onPressed: dialog.busy || b['enabled'] == false
                      ? null
                      : () => dialog.action(b['id'] as String),
                  child: Text(
                    text(b['text']),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
          ],
        ),
      );
    },
  );

  Widget componentWidget(SourceDialogComponent c) {
    final data = c.data;
    final error = dialog.fieldErrors.containsKey(c.id)
        ? dialog.fieldErrors[c.id] == null
              ? l10n(context).pluginDialogFieldRequired
              : text(dialog.fieldErrors[c.id])
        : null;
    final value = dialog.values[c.id];
    switch (c.type) {
      case 'text':
        return Text(
          text(data['text']),
          style: TextStyle(
            color: switch (data['tone']) {
              'error' => Theme.of(context).colorScheme.error,
              'secondary' => Theme.of(context).colorScheme.onSurfaceVariant,
              _ => null,
            },
          ),
        );
      case 'divider':
        return const Divider();
      case 'progress':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (data['text'] != null) Text(text(data['text'])),
            LinearProgressIndicator(value: (data['value'] as num?)?.toDouble()),
          ],
        );
      case 'image':
        return _DialogImage(
          bytes: c.image!,
          description: text(data['description']),
        );
      case 'input':
        return _DialogInput(
          value: value as String,
          enabled: !dialog.busy,
          obscure: data['obscure'] == true,
          maxLength: data['maxLength'] as int,
          keyboardType: data['keyboardType'] == 'number'
              ? TextInputType.number
              : TextInputType.text,
          label: text(data['label']),
          hint: text(data['placeholder']),
          error: error,
          onChanged: (v) => dialog.setValue(c.id, v),
        );
      case 'toggle':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(text(data['label'])),
              value: value as bool,
              onChanged: dialog.busy ? null : (v) => dialog.setValue(c.id, v),
            ),
            if (error != null)
              Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        );
      case 'select':
        final multiple = data['multiple'] == true;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text(data['label'])),
            Wrap(
              spacing: 8,
              children: [
                for (final raw in data['options'] as List)
                  Builder(
                    builder: (context) {
                      final option = raw as Map;
                      final selected = multiple
                          ? (value as List).contains(option['value'])
                          : value == option['value'];
                      void change(bool selected) {
                        if (multiple) {
                          final values = List<String>.from(value as List);
                          if (selected) {
                            values.add(option['value'] as String);
                          } else {
                            values.remove(option['value']);
                          }
                          dialog.setValue(c.id, values);
                        } else {
                          dialog.setValue(c.id, option['value'] as String);
                        }
                      }

                      return multiple
                          ? FilterChip(
                              label: Text(text(option['label'])),
                              selected: selected,
                              onSelected: dialog.busy ? null : change,
                            )
                          : ChoiceChip(
                              label: Text(text(option['label'])),
                              selected: selected,
                              onSelected: dialog.busy ? null : change,
                            );
                    },
                  ),
              ],
            ),
            if (error != null)
              Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        );
      case 'clickImage':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (data['description'] != null) Text(text(data['description'])),
            if (c.hintImage != null)
              SizedBox(height: 64, child: _DialogImage(bytes: c.hintImage!)),
            _DialogImage(
              bytes: c.image!,
              points: value as List,
              onPoint: dialog.busy
                  ? null
                  : (point) {
                      final points = List<Object>.from(
                        dialog.values[c.id] as List,
                      );
                      if (points.length >= (data['pointCount'] as int? ?? 32)) {
                        return;
                      }
                      points.add({
                        'x': point.dx.floor(),
                        'y': point.dy.floor(),
                      });
                      dialog.setValue(c.id, points);
                    },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: l10n(context).sourceLoginUndoPoint,
                  icon: const Icon(Icons.undo),
                  onPressed: dialog.busy || value.isEmpty
                      ? null
                      : () {
                          dialog.setValue(
                            c.id,
                            List<Object>.from(value)..removeLast(),
                          );
                        },
                ),
                IconButton(
                  tooltip: l10n(context).pluginDialogClearPoints,
                  icon: const Icon(Icons.clear_all),
                  onPressed: dialog.busy || value.isEmpty
                      ? null
                      : () => dialog.setValue(c.id, <Object>[]),
                ),
              ],
            ),
            if (error != null)
              Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _DialogInput extends StatefulWidget {
  const _DialogInput({
    required this.value,
    required this.enabled,
    required this.obscure,
    required this.maxLength,
    required this.keyboardType,
    required this.label,
    required this.hint,
    required this.error,
    required this.onChanged,
  });
  final String value, label, hint;
  final String? error;
  final bool enabled, obscure;
  final int maxLength;
  final TextInputType keyboardType;
  final ValueChanged<String> onChanged;
  @override
  State<_DialogInput> createState() => _DialogInputState();
}

class _DialogInputState extends State<_DialogInput> {
  late final _controller = TextEditingController(text: widget.value);
  @override
  void didUpdateWidget(covariant _DialogInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text != widget.value) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    enabled: widget.enabled,
    obscureText: widget.obscure,
    maxLength: widget.maxLength,
    inputFormatters: [
      TextInputFormatter.withFunction(
        (oldValue, newValue) =>
            newValue.text.length > widget.maxLength ? oldValue : newValue,
      ),
    ],
    keyboardType: widget.keyboardType,
    onChanged: widget.onChanged,
    decoration: InputDecoration(
      labelText: widget.label,
      hintText: widget.hint,
      errorText: widget.error,
      counterText: '',
      border: const OutlineInputBorder(),
    ),
  );
}

class _DialogImage extends StatefulWidget {
  const _DialogImage({
    required this.bytes,
    this.description = '',
    this.points,
    this.onPoint,
  });
  final Uint8List bytes;
  final String description;
  final List? points;
  final ValueChanged<Offset>? onPoint;
  @override
  State<_DialogImage> createState() => _DialogImageState();
}

class _DialogImageState extends State<_DialogImage> {
  late Future<Size> _size = inspect(widget.bytes);
  Future<Size> inspect(Uint8List bytes) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    try {
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      try {
        if (descriptor.width * descriptor.height > 4000000) {
          throw const FormatException('plugin_ui_image_too_large');
        }
        return Size(descriptor.width.toDouble(), descriptor.height.toDouble());
      } finally {
        descriptor.dispose();
      }
    } finally {
      buffer.dispose();
    }
  }

  @override
  void didUpdateWidget(covariant _DialogImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.bytes, widget.bytes)) {
      _size = inspect(widget.bytes);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Size>(
    future: _size,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Text(l10n(context).pluginDialogImageLoadFailed);
      }
      if (!snapshot.hasData) {
        return const SizedBox(
          height: 64,
          child: Center(child: CircularProgressIndicator()),
        );
      }
      return SizedBox(
        height: widget.points == null ? 200 : 240,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            final imageSize = snapshot.data!;
            final destination = Alignment.center.inscribe(
              applyBoxFit(BoxFit.contain, imageSize, size).destination,
              Offset.zero & size,
            );
            return GestureDetector(
              onTapUp: widget.onPoint == null
                  ? null
                  : (details) {
                      final point = captchaImagePoint(
                        details.localPosition,
                        size,
                        imageSize,
                      );
                      if (point != null) widget.onPoint!(point);
                    },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(
                    widget.bytes,
                    fit: BoxFit.contain,
                    semanticLabel: widget.description.isEmpty
                        ? null
                        : widget.description,
                    errorBuilder: (_, _, _) =>
                        Text(l10n(context).pluginDialogImageLoadFailed),
                  ),
                  for (var i = 0; i < (widget.points?.length ?? 0); i++)
                    Positioned(
                      left:
                          destination.left +
                          ((widget.points![i] as Map)['x'] as num) /
                              imageSize.width *
                              destination.width -
                          12,
                      top:
                          destination.top +
                          ((widget.points![i] as Map)['y'] as num) /
                              imageSize.height *
                              destination.height -
                          12,
                      child: IgnorePointer(
                        child: CircleAvatar(
                          radius: 12,
                          child: Text('${i + 1}'),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      );
    },
  );
}
