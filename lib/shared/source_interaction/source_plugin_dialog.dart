import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/interaction/source_dialog_model.dart';
import 'package:hazuki/services/source/interaction/source_ui_service.dart';
import 'package:hazuki/services/source/plugins/source_plugin_localization.dart';
import 'package:hazuki/shared/text/chinese_conversion_scope.dart';
import 'package:hazuki/widgets/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import '../source_account/source_account_dialog_support.dart';
import '../source_account/source_login_dialog_controller.dart';
import 'captcha_image_point.dart';
import 'source_plugin_icons.dart';

class SourcePluginDialog extends StatefulWidget {
  const SourcePluginDialog({
    super.key,
    required this.dialog,
    this.embedded = false,
    this.sheet = false,
    this.onUserClose,
    this.onOpenComic,
    this.onSearch,
  });
  final SourceDialogSession dialog;
  final bool embedded;

  /// 以底部面板布局渲染；路由由展示方创建。
  final bool sheet;
  final VoidCallback? onUserClose;

  /// 宿主导航入口；为空时漫画卡片与搜索型标签不可点击（如登录窗口内）。
  final ValueChanged<ExploreComic>? onOpenComic;
  final ValueChanged<String>? onSearch;
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
      final title = Column(
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
      );
      final body = Column(
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
      );
      final actions = [
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
      ];
      if (widget.sheet) {
        return IgnorePointer(
          ignoring: dialog.isClosed,
          child: Padding(
            // 底部面板内的输入框需要随键盘上移。
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .85,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 12, 8),
                    child: DefaultTextStyle(
                      style: Theme.of(context).textTheme.titleLarge!,
                      child: title,
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: body,
                    ),
                  ),
                  if (actions.isEmpty)
                    const SizedBox(height: 16)
                  else
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                      child: OverflowBar(
                        spacing: 8,
                        alignment: MainAxisAlignment.end,
                        children: actions,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }
      return IgnorePointer(
        ignoring: dialog.isClosed,
        child: SourceLoginStepContent(
          embedded: widget.embedded,
          backgroundColor: homeDialogBackgroundColor(context),
          title: title,
          content: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: 320,
              maxWidth: 320,
              maxHeight: MediaQuery.sizeOf(context).height * .55,
            ),
            child: SingleChildScrollView(child: body),
          ),
          actions: actions,
        ),
      );
    },
  );

  Future<void> copyValue(String value) async {
    unawaited(HapticFeedback.lightImpact());
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    unawaited(
      showHazukiPrompt(context, l10n(context).comicDetailCopiedPrefix(value)),
    );
  }

  Widget errorText(String? error) => error == null
      ? const SizedBox.shrink()
      : Text(
          error,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        );

  /// 与详情页信息栏一致的值标签：点击按 action 搜索或复制，长按始终复制。
  Widget valueChip(String value, Object? action) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final trimmed = value.trim();
    final onSearch = widget.onSearch;
    final VoidCallback? onPressed = switch (action) {
      'search' when onSearch != null && !dialog.busy => () => onSearch(trimmed),
      'copy' => () => unawaited(copyValue(trimmed)),
      _ => null,
    };
    return Tooltip(
      message: trimmed,
      child: GestureDetector(
        onLongPress: () => unawaited(copyValue(trimmed)),
        child: ActionChip(
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: cs.primary.withValues(alpha: 0.08),
          disabledColor: cs.primary.withValues(alpha: 0.08),
          side: BorderSide.none,
          labelPadding: const EdgeInsets.symmetric(horizontal: 4),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
          label: Text(
            trimmed,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          onPressed: onPressed,
        ),
      ),
    );
  }

  Widget contentButton(SourceDialogComponent c) {
    final data = c.data;
    final label = text(data['text']);
    final icon = sourcePluginIcon(data['icon']);
    final onPressed = dialog.busy || data['enabled'] == false
        ? null
        : () => dialog.action(c.id);
    final child = Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);
    final iconWidget = icon == null ? null : Icon(icon, size: 18);
    return switch (data['style']) {
      'icon' => IconButton(
        tooltip: label,
        onPressed: onPressed,
        icon: Icon(icon),
      ),
      'filled' =>
        iconWidget == null
            ? FilledButton(onPressed: onPressed, child: child)
            : FilledButton.icon(
                onPressed: onPressed,
                icon: iconWidget,
                label: child,
              ),
      'outlined' =>
        iconWidget == null
            ? OutlinedButton(onPressed: onPressed, child: child)
            : OutlinedButton.icon(
                onPressed: onPressed,
                icon: iconWidget,
                label: child,
              ),
      'text' =>
        iconWidget == null
            ? TextButton(onPressed: onPressed, child: child)
            : TextButton.icon(
                onPressed: onPressed,
                icon: iconWidget,
                label: child,
              ),
      _ =>
        iconWidget == null
            ? FilledButton.tonal(onPressed: onPressed, child: child)
            : FilledButton.tonalIcon(
                onPressed: onPressed,
                icon: iconWidget,
                label: child,
              ),
    };
  }

  Widget comicsWidget(SourceDialogComponent c) {
    final data = c.data;
    final open = widget.onOpenComic;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final tiles = [
      for (final raw in data['items'] as List)
        Builder(
          builder: (context) {
            final item = raw as Map;
            final comic = ExploreComic(
              id: item['id'] as String,
              title: item['title'] as String,
              subTitle: item['subtitle'] as String? ?? '',
              cover: item['cover'] as String? ?? '',
              sourceKey: dialog.pluginId,
            );
            return _DialogComicTile(
              comic: comic,
              cacheWidth: (112 * dpr).round(),
              onTap: open == null || dialog.busy ? null : () => open(comic),
            );
          },
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (data['title'] != null) ...[
          Text(
            text(data['title']),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
        ],
        if (data['layout'] == 'grid')
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: .5,
            children: tiles,
          )
        else
          SizedBox(
            height: 196,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: tiles.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, index) =>
                  SizedBox(width: 96, child: tiles[index]),
            ),
          ),
      ],
    );
  }

  Widget rowWidget(SourceDialogComponent c) {
    final align = c.data['align'];
    final children = <Widget>[];
    for (final child in c.children) {
      if (children.isNotEmpty) children.add(const SizedBox(width: 8));
      // 文字类默认占满剩余宽度，按钮、图片、评分按自身宽度排列。
      final flex =
          child.data['flex'] as int? ??
          (const {'text', 'richText', 'tags', 'progress'}.contains(child.type)
              ? 1
              : 0);
      final built = componentWidget(child, inRow: true);
      children.add(
        flex > 0
            ? Expanded(
                key: ValueKey((child.id, child.type)),
                flex: flex,
                child: built,
              )
            : KeyedSubtree(key: ValueKey((child.id, child.type)), child: built),
      );
    }
    return Row(
      mainAxisAlignment: switch (align) {
        'center' => MainAxisAlignment.center,
        'end' => MainAxisAlignment.end,
        'spaceBetween' => MainAxisAlignment.spaceBetween,
        _ => MainAxisAlignment.start,
      },
      children: children,
    );
  }

  Widget componentWidget(SourceDialogComponent c, {bool inRow = false}) {
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
          height: (data['height'] as num?)?.toDouble(),
          circle: data['shape'] == 'circle',
          intrinsicWidth: inRow,
        );
      case 'rating':
        final readOnly = data['readOnly'] == true;
        final label = data['label'] == null ? null : text(data['label']);
        final stars = _DialogRating(
          value: readOnly
              ? (data['initialValue'] as num? ?? 0).toDouble()
              : (value as num).toDouble(),
          max: data['max'] as int,
          allowHalf: data['allowHalf'] == true,
          size: readOnly ? 20 : 32,
          label: label ?? '',
          onChanged: readOnly || dialog.busy
              ? null
              : (v) => dialog.setValue(c.id, v),
        );
        if (label == null && error == null) return stars;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (label != null) Text(label),
            stars,
            if (error != null) errorText(error),
          ],
        );
      case 'row':
        return rowWidget(c);
      case 'button':
        return contentButton(c);
      case 'comics':
        return comicsWidget(c);
      case 'tags':
        final chips = Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final v in data['values'] as List)
              valueChip(v as String, data['action'] ?? 'search'),
          ],
        );
        if (data['label'] == null) return chips;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text(data['label']),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            chips,
          ],
        );
      case 'info':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final raw in data['rows'] as List)
              if (((raw as Map)['values'] as List).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 64,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 5, right: 8),
                          child: Text(
                            text(raw['label']),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final v in raw['values'] as List)
                              valueChip(v as String, raw['action'] ?? 'none'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        );
      case 'richText':
        return _DialogRichText(spans: data['spans'] as List, resolve: text);
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
    this.height,
    this.circle = false,
    this.intrinsicWidth = false,
  });
  final Uint8List bytes;
  final String description;
  final List? points;
  final ValueChanged<Offset>? onPoint;
  final double? height;

  /// 圆形裁剪（头像等），尺寸为 height 的正方形。
  final bool circle;

  /// row 内没有宽度约束，按图片比例自行确定宽度。
  final bool intrinsicWidth;
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
      final imageSize = snapshot.data!;
      final height = widget.height ?? (widget.points == null ? 200 : 240);
      final semanticLabel = widget.description.isEmpty
          ? null
          : widget.description;
      if (widget.circle) {
        final avatar = SizedBox.square(
          dimension: height,
          child: ClipOval(
            child: Image.memory(
              widget.bytes,
              fit: BoxFit.cover,
              semanticLabel: semanticLabel,
            ),
          ),
        );
        return widget.intrinsicWidth
            ? avatar
            : Align(alignment: Alignment.centerLeft, child: avatar);
      }
      if (widget.intrinsicWidth) {
        return SizedBox(
          width: height * imageSize.width / imageSize.height,
          height: height,
          child: Image.memory(
            widget.bytes,
            fit: BoxFit.contain,
            semanticLabel: semanticLabel,
          ),
        );
      }
      return SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
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

/// 星级评分：只读时按小数部分填充，可交互时点按或横向拖动选择整星/半星。
class _DialogRating extends StatefulWidget {
  const _DialogRating({
    required this.value,
    required this.max,
    required this.allowHalf,
    required this.size,
    required this.label,
    required this.onChanged,
  });
  final double value;
  final int max;
  final bool allowHalf;
  final double size;
  final String label;
  final ValueChanged<num>? onChanged;
  @override
  State<_DialogRating> createState() => _DialogRatingState();
}

class _DialogRatingState extends State<_DialogRating> {
  // 拖动过程中只更新本地显示，松手后再提交，避免 notifyChange 逐帧触发事件。
  num? _dragValue;

  num resolve(double dx) {
    final steps = widget.allowHalf ? 2 : 1;
    final raw = (dx / widget.size).clamp(0.0, widget.max.toDouble());
    final value = ((raw * steps).ceil() / steps).clamp(
      1 / steps,
      widget.max.toDouble(),
    );
    return widget.allowHalf ? value : value.toInt();
  }

  num stepped(int direction) {
    final step = widget.allowHalf ? .5 : 1;
    final next = (widget.value + step * direction).clamp(0, widget.max);
    return widget.allowHalf ? next : next.toInt();
  }

  String describe(num value) =>
      '${_formatRating(value.toDouble())} / '
      '${widget.max}';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final value = (_dragValue ?? widget.value).toDouble();
    final stars = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < widget.max; i++)
          SizedBox.square(
            dimension: widget.size,
            child: Stack(
              children: [
                Icon(
                  Icons.star_rounded,
                  size: widget.size,
                  color: colors.outlineVariant,
                ),
                ClipRect(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    widthFactor: (value - i).clamp(0.0, 1.0),
                    child: Icon(
                      Icons.star_rounded,
                      size: widget.size,
                      color: const Color(0xFFFFB300),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
    final onChanged = widget.onChanged;
    if (onChanged == null) {
      return Semantics(
        label: widget.label,
        value: describe(value),
        child: ExcludeSemantics(child: stars),
      );
    }
    return Semantics(
      slider: true,
      label: widget.label,
      value: describe(value),
      increasedValue: describe(stepped(1)),
      decreasedValue: describe(stepped(-1)),
      onIncrease: () => onChanged(stepped(1)),
      onDecrease: () => onChanged(stepped(-1)),
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            final next = resolve(details.localPosition.dx);
            // 再次点按当前分值视为清除评分。
            onChanged(next == widget.value ? 0 : next);
          },
          onHorizontalDragUpdate: (details) =>
              setState(() => _dragValue = resolve(details.localPosition.dx)),
          onHorizontalDragEnd: (_) {
            final next = _dragValue;
            setState(() => _dragValue = null);
            if (next != null) onChanged(next);
          },
          onHorizontalDragCancel: () => setState(() => _dragValue = null),
          child: stars,
        ),
      ),
    );
  }
}

String _formatRating(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(2);

class _DialogComicTile extends StatelessWidget {
  const _DialogComicTile({
    required this.comic,
    required this.cacheWidth,
    required this.onTap,
  });
  final ExploreComic comic;
  final int cacheWidth;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget placeholder([IconData? icon]) => Container(
      color: theme.colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: icon == null ? null : Icon(icon),
    );
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: comic.cover.isEmpty
                  ? placeholder(Icons.image_not_supported_outlined)
                  : HazukiCachedImage(
                      url: comic.cover,
                      sourceKey: comic.sourceKey,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      cacheWidth: cacheWidth,
                      animateOnLoad: true,
                      loadAnimationBeginScale: 1,
                      loading: placeholder(),
                      error: placeholder(Icons.broken_image_outlined),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            convertChineseText(context, comic.title),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
          if (comic.subTitle.isNotEmpty)
            Text(
              comic.subTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

/// 受限富文本：仅支持加粗、斜体、配色与链接，换行即分段。
class _DialogRichText extends StatefulWidget {
  const _DialogRichText({required this.spans, required this.resolve});
  final List spans;
  final String Function(Object?) resolve;
  @override
  State<_DialogRichText> createState() => _DialogRichTextState();
}

class _DialogRichTextState extends State<_DialogRichText> {
  // 识别器只依赖链接，组件数据不变时复用，避免每次重建都重新分配。
  List<TapGestureRecognizer?> _recognizers = const [];

  @override
  void initState() {
    super.initState();
    _createRecognizers();
  }

  @override
  void didUpdateWidget(covariant _DialogRichText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.spans, widget.spans)) {
      _disposeRecognizers();
      _createRecognizers();
    }
  }

  void _createRecognizers() {
    _recognizers = [
      for (final raw in widget.spans)
        switch ((raw as Map)['link']) {
          final String link =>
            TapGestureRecognizer()
              ..onTap = () => unawaited(
                launchUrl(
                  Uri.parse(link),
                  mode: LaunchMode.externalApplication,
                ),
              ),
          _ => null,
        },
    ];
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer?.dispose();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Text.rich(
      TextSpan(
        children: [
          for (var i = 0; i < widget.spans.length; i++)
            _span(widget.spans[i] as Map, _recognizers[i], colors),
        ],
      ),
    );
  }

  TextSpan _span(
    Map span,
    TapGestureRecognizer? recognizer,
    ColorScheme colors,
  ) {
    final link = recognizer != null;
    return TextSpan(
      text: widget.resolve(span['text']),
      recognizer: recognizer,
      mouseCursor: link ? SystemMouseCursors.click : null,
      style: TextStyle(
        fontWeight: span['bold'] == true ? FontWeight.w700 : null,
        fontStyle: span['italic'] == true ? FontStyle.italic : null,
        decoration: link ? TextDecoration.underline : null,
        color: link
            ? colors.primary
            : switch (span['tone']) {
                'primary' => colors.primary,
                'secondary' => colors.onSurfaceVariant,
                'error' => colors.error,
                _ => null,
              },
      ),
    );
  }
}
