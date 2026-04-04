part of 'source_runtime_widgets.dart';

extension _SourceRuntimeDialogActions on _SourceUpdateDialogCardState {
  Future<void> _downloadUpdate() async {
    widget.dismissible.value = false;
    _updateDialogState(() {
      _phase = _SourceUpdateDialogPhase.downloading;
      _errorText = null;
      _progress = 0;
      _indeterminate = true;
    });

    final ok = await HazukiSourceService.instance.downloadJmSourceAndReload(
      onProgress: (received, total) {
        _updateDialogState(() {
          if (total > 0) {
            _indeterminate = false;
            _progress = (received / total).clamp(0.0, 1.0);
          } else {
            _indeterminate = true;
          }
        });
      },
    );

    if (!mounted) {
      return;
    }

    if (ok) {
      widget.onDownloadCompleted();
      widget.dismissible.value = true;
      _updateDialogState(() {
        _phase = _SourceUpdateDialogPhase.restartRequired;
        _indeterminate = false;
        _progress = 1;
      });
      return;
    }

    widget.dismissible.value = false;
    _updateDialogState(() {
      _phase = _SourceUpdateDialogPhase.available;
      _errorText = l10n(context).sourceUpdateDownloadFailed;
    });
  }
}
