import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:hazuki/features/reader/support/reader_controller_support.dart';
import 'package:hazuki/features/reader/support/reader_session_controller.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/widgets/widgets.dart';

class ReaderSaveImageController {
  ReaderSaveImageController({
    required ReaderContextGetter context,
    required ThemeData Function(BuildContext context) resolveReaderTheme,
    required ReaderSessionController sessionController,
    required ReaderIsMounted isMounted,
    required ReaderLogEvent logEvent,
    required ReaderLogPayloadBuilder logPayload,
    required String comicId,
    required String epId,
  }) : _context = context,
       _resolveReaderTheme = resolveReaderTheme,
       _sessionController = sessionController,
       _isMounted = isMounted,
       _logEvent = logEvent,
       _logPayload = logPayload,
       _comicId = comicId,
       _epId = epId;

  final ReaderContextGetter _context;
  final ThemeData Function(BuildContext context) _resolveReaderTheme;
  final ReaderSessionController _sessionController;
  final ReaderIsMounted _isMounted;
  final ReaderLogEvent _logEvent;
  final ReaderLogPayloadBuilder _logPayload;
  final String _comicId;
  final String _epId;

  Future<void> showSaveImageDialog(String imageUrl) async {
    unawaited(HapticFeedback.heavyImpact());
    final context = _context();
    final strings = l10n(context);
    final dialogTheme = _resolveReaderTheme(context);
    _logEvent(
      'Reader save image dialog opened',
      source: 'reader_media',
      content: _logPayload({'imageUrl': imageUrl}),
    );
    final shouldSave = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: strings.commonClose,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(
          scale: CurvedAnimation(
            parent: anim1,
            curve: Curves.easeOutBack,
            reverseCurve: Curves.easeInBack,
          ).value,
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
      pageBuilder: (dialogContext, anim1, anim2) {
        return Theme(
          data: dialogTheme,
          child: AlertDialog(
            backgroundColor: dialogTheme.colorScheme.surfaceContainerHigh,
            title: Text(strings.readerSaveImageTitle),
            content: Text(strings.readerSaveImageContent),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(strings.commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(strings.commonSave),
              ),
            ],
          ),
        );
      },
    );
    if (shouldSave != true || !_isMounted()) {
      _logEvent(
        'Reader save image cancelled',
        source: 'reader_media',
        content: _logPayload({'imageUrl': imageUrl}),
      );
      return;
    }
    _logEvent(
      'Reader save image confirmed',
      source: 'reader_media',
      content: _logPayload({'imageUrl': imageUrl}),
    );
    try {
      final prepared = await _prepareImageForSave(imageUrl);
      final directory = await _resolveSaveDirectory();
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      final file = File(
        '${directory.path}/${_resolveSaveName(imageUrl, prepared.extension)}',
      );
      await file.writeAsBytes(prepared.bytes, flush: true);
      if (!_isMounted()) {
        return;
      }
      _logEvent(
        'Reader image saved',
        source: 'reader_media',
        content: _logPayload({'imageUrl': imageUrl, 'savedPath': file.path}),
      );
      unawaited(showHazukiPrompt(_context(), strings.comicDetailSavedToPath));
    } catch (error) {
      _logEvent(
        'Reader image save failed',
        level: 'error',
        source: 'reader_media',
        content: _logPayload({'imageUrl': imageUrl, 'error': '$error'}),
      );
      if (!_isMounted()) {
        return;
      }
      unawaited(
        showHazukiPrompt(
          _context(),
          strings.comicDetailSaveFailed('$error'),
          isError: true,
        ),
      );
    }
  }

  Future<_ReaderPreparedSaveImage> _prepareImageForSave(String imageUrl) async {
    if (_sessionController.isLocalImagePath(imageUrl)) {
      final file = File(_sessionController.normalizeLocalImagePath(imageUrl));
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

    final prepared = await _sessionController.prepareImageForSave(
      imageUrl,
      comicId: _comicId,
      epId: _epId,
    );
    return _ReaderPreparedSaveImage(
      bytes: prepared.bytes,
      extension: prepared.extension,
    );
  }

  Future<Directory> _resolveSaveDirectory() async {
    if (Platform.isWindows) {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      return Directory('$exeDir/Saved_Images');
    }
    return Directory('/storage/emulated/0/Pictures/Hazuki');
  }

  String _resolveSaveName(String imageUrl, String outputExtension) {
    final uri = Uri.tryParse(imageUrl);
    final lastSegment = uri?.pathSegments.isNotEmpty == true
        ? uri!.pathSegments.last
        : '';
    final defaultName =
        'hazuki_${DateTime.now().millisecondsSinceEpoch}.$outputExtension';
    final fileName = lastSegment.isEmpty ? defaultName : lastSegment;
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
