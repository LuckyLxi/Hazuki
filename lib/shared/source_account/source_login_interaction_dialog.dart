import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/services/source/account/source_login_interaction.dart';

import 'source_account_dialogs.dart';
import 'source_browser_authorization_dialog.dart';
import 'source_external_authorization_dialog.dart';
import 'source_login_interaction_text.dart';
import 'source_login_dialog_controller.dart';

/// Maps logical widget coordinates to unscaled image pixels, excluding padding.
Offset? captchaImagePoint(Offset local, Size canvas, Size image) {
  if (image.isEmpty || canvas.isEmpty) return null;
  final fitted = applyBoxFit(BoxFit.contain, image, canvas);
  final destination = Alignment.center.inscribe(
    fitted.destination,
    Offset.zero & canvas,
  );
  if (!destination.contains(local)) return null;
  return Offset(
    (local.dx - destination.left) * image.width / destination.width,
    (local.dy - destination.top) * image.height / destination.height,
  );
}

Uint8List _imageBytes(Object? raw) {
  if (raw is Uint8List) return raw;
  if (raw is List && raw.every((v) => v is int && v >= 0 && v <= 255)) {
    return Uint8List.fromList(raw.cast<int>());
  }
  if (raw is String &&
      raw.startsWith('data:image/') &&
      raw.contains(';base64,')) {
    return base64Decode(raw.substring(raw.indexOf(',') + 1));
  }
  throw const FormatException('login_invalid_captcha_image');
}

Future<Object?> showSourceLoginInteraction(
  BuildContext context,
  Map<String, dynamic> request,
  SourceLoginCancellation cancellation, {
  SourceLoginDialogController? dialogController,
}) async {
  cancellation.check();
  if (!context.mounted) {
    cancellation.cancel();
    cancellation.check();
  }
  if (request['type'] == 'browserAuthorization') {
    return showSourceBrowserAuthorization(
      context,
      request,
      cancellation,
      dialogController: dialogController,
    );
  }
  if (request['type'] == 'externalAuthorization') {
    return showSourceExternalAuthorization(
      context,
      request,
      cancellation,
      dialogController: dialogController,
    );
  }
  if (!const {'text', 'clickCaptcha'}.contains(request['type'])) {
    throw const FormatException('login_invalid_interaction');
  }
  if (dialogController != null) {
    return dialogController.present(
      (finish) => _LoginInteraction(
        request: request,
        cancellation: cancellation,
        onComplete: finish,
      ),
      cancellation,
    );
  }
  final result = await Future.any<Object?>([
    showHomeAnimatedDialog<Object>(
      context,
      child: _LoginInteraction(request: request, cancellation: cancellation),
    ),
    cancellation.whenCancelled.then((_) => throw const SourceLoginCancelled()),
  ]);
  if (result == null) cancellation.cancel();
  cancellation.check();
  return result;
}

class _LoginInteraction extends StatefulWidget {
  const _LoginInteraction({
    required this.request,
    required this.cancellation,
    this.onComplete,
  });
  final Map<String, dynamic> request;
  final SourceLoginCancellation cancellation;
  final ValueChanged<Object?>? onComplete;
  @override
  State<_LoginInteraction> createState() => _LoginInteractionState();
}

class _LoginInteractionState extends State<_LoginInteraction> {
  late final _text = TextEditingController(
    text: widget.request['initialValue'] as String? ?? '',
  );
  final _points = <Offset>[];
  Uint8List? _image;
  Uint8List? _hint;
  Size? _imageSize;
  Object? _error;
  ModalRoute<Object?>? _route;
  bool _answered = false;

  void _finish(Object value) {
    if (_answered || widget.cancellation.isCancelled) return;
    _answered = true;
    if (widget.onComplete != null) {
      widget.onComplete!(value);
    } else {
      Navigator.pop(context, value);
    }
  }

  @override
  void initState() {
    super.initState();
    widget.cancellation.addListener(_cancel);
    if (widget.request['type'] == 'clickCaptcha') _decode();
  }

  Future<void> _decode() async {
    try {
      _image = _imageBytes(widget.request['image']);
      if (widget.request['hintImage'] != null) {
        _hint = _imageBytes(widget.request['hintImage']);
      }
      final codec = await ui.instantiateImageCodec(_image!);
      try {
        final frame = await codec.getNextFrame();
        final size = Size(
          frame.image.width.toDouble(),
          frame.image.height.toDouble(),
        );
        frame.image.dispose();
        if (mounted) setState(() => _imageSize = size);
      } finally {
        codec.dispose();
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
    if (widget.cancellation.isCancelled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _cancel());
    }
  }

  void _cancel() {
    if (widget.onComplete != null) return;
    scheduleMicrotask(() {
      final route = _route;
      if (mounted && route != null && route.isActive) {
        if (route.isCurrent) {
          Navigator.of(context).pop();
        } else {
          Navigator.of(context).removeRoute(route);
        }
      }
    });
  }

  @override
  void dispose() {
    widget.cancellation.removeListener(_cancel);
    if (!_answered) widget.cancellation.cancel();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final click = widget.request['type'] == 'clickCaptcha';
    const captchaButtonStyle = ButtonStyle(
      padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 8)),
      minimumSize: WidgetStatePropertyAll(Size(0, 48)),
    );
    final cancel = TextButton(
      style: click ? captchaButtonStyle : null,
      onPressed: widget.cancellation.cancel,
      child: Text(strings.commonCancel, textAlign: TextAlign.center),
    );
    final confirm = FilledButton(
      style: click ? captchaButtonStyle : null,
      onPressed: click
          ? _points.isEmpty ||
                    (widget.request['pointCount'] != null &&
                        _points.length != widget.request['pointCount'])
                ? null
                : () => _finish({
                    'status': 'submitted',
                    'points': [
                      for (final p in _points)
                        {'x': p.dx.floor(), 'y': p.dy.floor()},
                    ],
                  })
          : _text.text.isEmpty
          ? null
          : () => _finish(_text.text),
      child: Text(strings.commonConfirm, textAlign: TextAlign.center),
    );
    return SourceLoginStepContent(
      embedded: widget.onComplete != null,
      backgroundColor: homeDialogBackgroundColor(context),
      title: Text(
        loginInteractionText(
          context,
          widget.request['title'] ?? strings.homeLoginTitle,
        ),
      ),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.request['message'] != null)
                Text(loginInteractionText(context, widget.request['message'])),
              if (!click)
                TextField(
                  controller: _text,
                  autofocus: true,
                  obscureText: widget.request['obscure'] == true,
                  keyboardType: widget.request['keyboardType'] == 'number'
                      ? TextInputType.number
                      : TextInputType.text,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                ),
              if (_hint != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    height: 64,
                    child: Image.memory(
                      _hint!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) =>
                          Text(strings.sourceLoginImageLoadFailed),
                    ),
                  ),
                ),
              // Decoding must not change the step's layout on the next frame:
              // consecutive size changes make AnimatedSize snap to its target.
              if (click)
                SizedBox(
                  height: 240,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: _error != null
                        ? Center(
                            key: const ValueKey('captcha-image-error'),
                            child: Text(strings.sourceLoginImageLoadFailed),
                          )
                        : _imageSize == null
                        ? const Center(
                            key: ValueKey('captcha-image-loading'),
                            child: CircularProgressIndicator(),
                          )
                        : LayoutBuilder(
                            key: const ValueKey('captcha-image-ready'),
                            builder: (context, constraints) {
                              final size = Size(constraints.maxWidth, 240);
                              final destination = Alignment.center.inscribe(
                                applyBoxFit(
                                  BoxFit.contain,
                                  _imageSize!,
                                  size,
                                ).destination,
                                Offset.zero & size,
                              );
                              return GestureDetector(
                                key: const ValueKey('login-click-captcha'),
                                onTapUp: (details) {
                                  final point = captchaImagePoint(
                                    details.localPosition,
                                    size,
                                    _imageSize!,
                                  );
                                  final limit =
                                      (widget.request['pointCount'] as num?)
                                          ?.toInt() ??
                                      32;
                                  if (point != null && _points.length < limit) {
                                    setState(() => _points.add(point));
                                  }
                                },
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.memory(_image!, fit: BoxFit.contain),
                                    for (var i = 0; i < _points.length; i++)
                                      Positioned(
                                        left:
                                            destination.left +
                                            _points[i].dx /
                                                _imageSize!.width *
                                                destination.width -
                                            12,
                                        top:
                                            destination.top +
                                            _points[i].dy /
                                                _imageSize!.height *
                                                destination.height -
                                            12,
                                        child: IgnorePointer(
                                          child: CircleAvatar(
                                            radius: 12,
                                            backgroundColor: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            foregroundColor: Theme.of(
                                              context,
                                            ).colorScheme.onPrimary,
                                            child: Text(
                                              '${i + 1}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: click
          ? [
              Row(
                key: const ValueKey('login-captcha-actions'),
                mainAxisAlignment: MainAxisAlignment.end,
                spacing: 8,
                children: [
                  Flexible(child: cancel),
                  Flexible(
                    flex: 2,
                    child: TextButton(
                      style: captchaButtonStyle,
                      onPressed: () => _finish({'status': 'refresh'}),
                      child: Text(
                        strings.sourceLoginRefresh,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _points.isEmpty
                        ? null
                        : () => setState(() => _points.removeLast()),
                    tooltip: strings.sourceLoginUndoPoint,
                    icon: const Icon(Icons.undo),
                  ),
                  Flexible(child: confirm),
                ],
              ),
            ]
          : [cancel, confirm],
    );
  }
}
