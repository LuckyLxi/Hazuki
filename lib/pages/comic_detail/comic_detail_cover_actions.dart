part of '../comic_detail_page.dart';

extension _ComicDetailCoverActionsExtension on _ComicDetailPageState {
  Future<void> _saveImageToDownloads(String imageUrl) async {
    try {
      final bytes = await HazukiSourceService.instance.downloadImageBytes(
        imageUrl,
      );
      final uri = Uri.tryParse(imageUrl);
      final lastSegment = uri?.pathSegments.isNotEmpty == true
          ? uri!.pathSegments.last
          : '';
      final defaultName = 'hazuki_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final fileName = lastSegment.isEmpty
          ? defaultName
          : lastSegment.split('?').first;
      Directory directory;
      if (Platform.isWindows) {
        final exeDir = File(Platform.resolvedExecutable).parent.path;
        directory = Directory('$exeDir/Saved_Images');
      } else {
        directory = Directory('/storage/emulated/0/Pictures/Hazuki');
      }
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      if (Platform.isAndroid) {
        await _ComicDetailPageState._mediaChannel.invokeMethod<bool>('scanFile', {
          'path': file.path,
        });
      }
      if (!mounted) {
        return;
      }
      unawaited(
        showHazukiPrompt(context, l10n(context).comicDetailSavedToPath),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).comicDetailSaveFailed('$e'),
          isError: true,
        ),
      );
    }
  }

  Future<void> _showCoverActions(String imageUrl) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final themedData = _buildDetailTheme(Theme.of(context));
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Theme(
          data: themedData,
          child: AlertDialog(
            title: Text(l10n(context).comicDetailSaveImage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n(context).commonCancel),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  unawaited(_saveImageToDownloads(imageUrl));
                },
                child: Text(l10n(context).commonSave),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showCoverPreview(String imageUrl) async {
    final normalized = imageUrl.trim();
    if (normalized.isEmpty) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();

    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black45,
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (dialogContext, animation, secondaryAnimation) {
          return _ComicCoverPreviewPage(
            imageUrl: normalized,
            heroTag: widget.heroTag,
            onLongPress: () {
              unawaited(HapticFeedback.selectionClick());
              unawaited(_showCoverActions(normalized));
            },
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(opacity: curved, child: child);
        },
      ),
    );
  }
}
