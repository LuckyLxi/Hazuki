part of '../reader_page.dart';

extension _ReaderMediaActionsExtension on _ReaderPageState {
  Widget _wrapImageWidget(Widget imageWidget, String url) {
    Widget result = imageWidget;
    if (_longPressToSave) {
      result = GestureDetector(
        onLongPress: () => _showSaveImageDialog(url),
        child: result,
      );
    }
    return result;
  }

  Future<void> _showSaveImageDialog(String imageUrl) async {
    unawaited(HapticFeedback.heavyImpact());
    final strings = l10n(context);
    _logReaderEvent(
      'Reader save image dialog opened',
      source: 'reader_media',
      content: _readerLogPayload({
        'imageUrl': imageUrl,
      }),
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
        return AlertDialog(
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
        );
      },
    );
    if (shouldSave != true || !mounted) {
      _logReaderEvent(
        'Reader save image cancelled',
        source: 'reader_media',
        content: _readerLogPayload({
          'imageUrl': imageUrl,
        }),
      );
      return;
    }
    _logReaderEvent(
      'Reader save image confirmed',
      source: 'reader_media',
      content: _readerLogPayload({
        'imageUrl': imageUrl,
      }),
    );
    try {
      final sourceService = HazukiSourceService.instance;
      Uint8List bytes;
      String outputExtension = 'png';

      if (sourceService.isLocalImagePath(imageUrl)) {
        final file = File(sourceService.normalizeLocalImagePath(imageUrl));
        bytes = await file.readAsBytes();
        final localExtMatch = RegExp(
          r'\.([a-zA-Z0-9]+)$',
          caseSensitive: false,
        ).firstMatch(file.path);
        outputExtension =
            localExtMatch?.group(1)?.toLowerCase().trim().isNotEmpty == true
            ? localExtMatch!.group(1)!.toLowerCase()
            : 'jpg';
      } else {
        final prepared = await sourceService.prepareChapterImageData(
          imageUrl,
          comicId: widget.comicId,
          epId: widget.epId,
        );
        bytes = prepared.bytes;
        outputExtension = prepared.extension;
      }

      final uri = Uri.tryParse(imageUrl);
      final lastSegment = uri?.pathSegments.isNotEmpty == true
          ? uri!.pathSegments.last
          : '';
      final defaultName =
          'hazuki_${DateTime.now().millisecondsSinceEpoch}.$outputExtension';
      final fileName = lastSegment.isEmpty
          ? defaultName
          : lastSegment.split('?').first;
      final saveName = fileName.contains('.')
          ? fileName.replaceAll(
              RegExp(r'\.([a-zA-Z0-9]+)$', caseSensitive: false),
              '.$outputExtension',
            )
          : '$fileName.$outputExtension';
      final directory = Directory('/storage/emulated/0/Pictures/Hazuki');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      final file = File('${directory.path}/$saveName');
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) {
        return;
      }
      _logReaderEvent(
        'Reader image saved',
        source: 'reader_media',
        content: _readerLogPayload({
          'imageUrl': imageUrl,
          'savedPath': file.path,
        }),
      );
      unawaited(showHazukiPrompt(context, strings.comicDetailSavedToPath));
    } catch (e) {
      _logReaderEvent(
        'Reader image save failed',
        level: 'error',
        source: 'reader_media',
        content: _readerLogPayload({
          'imageUrl': imageUrl,
          'error': '$e',
        }),
      );
      if (!mounted) {
        return;
      }
      unawaited(
        showHazukiPrompt(
          context,
          strings.comicDetailSaveFailed('$e'),
          isError: true,
        ),
      );
    }
  }
}

