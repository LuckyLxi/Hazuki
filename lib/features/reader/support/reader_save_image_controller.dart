import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:hazuki/features/reader/support/reader_controller_support.dart';
import 'package:hazuki/features/reader/support/reader_image_actions_service.dart';
import 'package:hazuki/features/reader/view/reader_image_actions_sheet.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/widgets/widgets.dart';

class ReaderSaveImageController {
  ReaderSaveImageController({
    required ReaderContextGetter context,
    required ThemeData Function(BuildContext context) resolveReaderTheme,
    required SourceReaderGateway sourceReader,
    required ReaderIsMounted isMounted,
    required ReaderLogEvent logEvent,
    required ReaderLogPayloadBuilder logPayload,
    required String comicId,
    required String epId,
    required String sourceKey,
    ReaderImageActionsService imageActions = const ReaderImageActionsService(),
  }) : _context = context,
       _resolveReaderTheme = resolveReaderTheme,
       _sourceReader = sourceReader,
       _isMounted = isMounted,
       _logEvent = logEvent,
       _logPayload = logPayload,
       _comicId = comicId,
       _epId = epId,
       _sourceKey = sourceKey,
       _imageActions = imageActions;

  final ReaderContextGetter _context;
  final ThemeData Function(BuildContext context) _resolveReaderTheme;
  final SourceReaderGateway _sourceReader;
  final ReaderIsMounted _isMounted;
  final ReaderLogEvent _logEvent;
  final ReaderLogPayloadBuilder _logPayload;
  final String _comicId;
  final String _epId;
  final String _sourceKey;
  final ReaderImageActionsService _imageActions;
  bool _actionsOpen = false;

  Future<void> showSaveImageDialog(String imageUrl) async {
    if (_actionsOpen || !_isMounted()) return;
    _actionsOpen = true;
    try {
      await _showImageActions(imageUrl);
    } finally {
      _actionsOpen = false;
    }
  }

  Future<void> _showImageActions(String imageUrl) async {
    unawaited(HapticFeedback.heavyImpact());
    final context = _context();
    final strings = l10n(context);
    final dialogTheme = _resolveReaderTheme(context);
    _logEvent(
      'Reader image actions opened',
      source: 'reader_media',
      content: _logPayload({'imageUrl': imageUrl}),
    );
    final action = await showModalBottomSheet<ReaderImageAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      elevation: 0,
      showDragHandle: false,
      constraints: const BoxConstraints(maxWidth: 560),
      sheetAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 400),
        // A small overshoot lifts the sheet gently before it settles.
        curve: Cubic(0.2, 0.9, 0.3, 1.15),
      ),
      builder: (dialogContext) {
        return Theme(data: dialogTheme, child: const ReaderImageActionsSheet());
      },
    );
    if (action == null || !_isMounted()) {
      _logEvent(
        'Reader image actions cancelled',
        source: 'reader_media',
        content: _logPayload({'imageUrl': imageUrl}),
      );
      return;
    }
    _logEvent(
      'Reader image action selected',
      source: 'reader_media',
      content: _logPayload({'imageUrl': imageUrl, 'action': action.name}),
    );
    try {
      final prepared = await _prepareImageForSave(imageUrl);
      if (!_isMounted()) return;
      String? savedPath;
      switch (action) {
        case ReaderImageAction.share:
          await _imageActions.shareImage(prepared.bytes, prepared.extension);
        case ReaderImageAction.copy:
          await _imageActions.copyImage(prepared.bytes, prepared.extension);
        case ReaderImageAction.save:
          savedPath = await _imageActions.saveImage(
            prepared.bytes,
            prepared.extension,
            _resolveSaveName(imageUrl, prepared.extension),
          );
      }
      if (!_isMounted()) {
        return;
      }
      _logEvent(
        'Reader image action completed',
        source: 'reader_media',
        content: _logPayload({
          'imageUrl': imageUrl,
          'action': action.name,
          'savedPath': ?savedPath,
        }),
      );
      if (action != ReaderImageAction.share) {
        unawaited(
          showHazukiPrompt(
            _context(),
            action == ReaderImageAction.copy
                ? strings.readerImageCopied
                : strings.comicDetailSavedToPath,
          ),
        );
      }
    } catch (error) {
      _logEvent(
        'Reader image action failed',
        level: 'error',
        source: 'reader_media',
        content: _logPayload({
          'imageUrl': imageUrl,
          'action': action.name,
          'error': '$error',
        }),
      );
      if (!_isMounted()) {
        return;
      }
      unawaited(
        showHazukiPrompt(_context(), switch (action) {
          ReaderImageAction.share => strings.readerShareImageFailed('$error'),
          ReaderImageAction.copy => strings.readerCopyImageFailed('$error'),
          ReaderImageAction.save => strings.comicDetailSaveFailed('$error'),
        }, isError: true),
      );
    }
  }

  Future<_ReaderPreparedSaveImage> _prepareImageForSave(String imageUrl) async {
    if (_sourceReader.isLocalImagePath(imageUrl)) {
      final file = File(_sourceReader.normalizeLocalImagePath(imageUrl));
      final bytes = await file.readAsBytes();
      final localExtMatch = RegExp(
        r'\.([a-zA-Z0-9]+)$',
        caseSensitive: false,
      ).firstMatch(file.path);
      final extension =
          localExtMatch?.group(1)?.toLowerCase().trim().isNotEmpty == true
          ? localExtMatch!.group(1)!.toLowerCase()
          : 'jpg';
      return _ReaderPreparedSaveImage(bytes: bytes, extension: extension);
    }

    final prepared = await _sourceReader.prepareChapterImageData(
      imageUrl,
      comicId: _comicId,
      epId: _epId,
      sourceKey: _sourceKey,
    );
    return _ReaderPreparedSaveImage(
      bytes: prepared.bytes,
      extension: prepared.extension,
    );
  }

  String _resolveSaveName(String imageUrl, String outputExtension) {
    final uri = Uri.tryParse(imageUrl);
    final lastSegment = uri?.pathSegments.isNotEmpty == true
        ? uri!.pathSegments.last
        : '';
    final defaultName =
        'hazuki_${DateTime.now().millisecondsSinceEpoch}.$outputExtension';
    final fileName = lastSegment.isEmpty
        ? defaultName
        : lastSegment.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_');
    return fileName.contains('.')
        ? fileName.replaceAll(
            RegExp(r'\.([a-zA-Z0-9]+)$', caseSensitive: false),
            '.$outputExtension',
          )
        : '$fileName.$outputExtension';
  }
}

class _ReaderPreparedSaveImage {
  const _ReaderPreparedSaveImage({
    required this.bytes,
    required this.extension,
  });

  final Uint8List bytes;
  final String extension;
}
