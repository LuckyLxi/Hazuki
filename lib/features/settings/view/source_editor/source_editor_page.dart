import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/widgets/widgets.dart';
import 'source_editor_content.dart';
import 'source_editor_controller.dart';
import 'source_editor_restore_dialog.dart';
import '../settings_group.dart';

class ComicSourceEditorPage extends StatefulWidget {
  const ComicSourceEditorPage({super.key, required this.sourceService});

  final SourceRuntimeGateway sourceService;

  @override
  State<ComicSourceEditorPage> createState() => _ComicSourceEditorPageState();
}

class _ComicSourceEditorPageState extends State<ComicSourceEditorPage> {
  final _controller = SourceCodeEditingController();

  String _initialContent = '';
  String? _loadErrorText;
  String? _inlineErrorText;
  bool _loading = true;
  bool _saving = false;
  bool _controllerRebuildScheduled = false;

  AppLocalizations get _strings => l10n(context);
  bool get _hasChanges => _controller.text != _initialContent;

  String get _pageTitle => _strings.advancedEditSourceTitle;
  String get _saveLabel => _strings.commonSave;
  String get _loadingText => _strings.sourceEditorLoading;
  String get _retryLabel => _strings.commonRetry;
  String get _saveSuccessText => _strings.sourceEditorSaved;
  String _loadFailedText(Object error) =>
      _strings.sourceEditorLoadFailed(error);
  String _saveFailedText(Object error) =>
      _strings.sourceEditorSaveFailed(error);

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _loadSource();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (!mounted) {
      return;
    }
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_controllerRebuildScheduled) {
        return;
      }
      _controllerRebuildScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _controllerRebuildScheduled = false;
        if (mounted) {
          setState(() {});
        }
      });
      return;
    }
    setState(() {});
  }

  Future<void> _loadSource() async {
    setState(() {
      _loading = true;
      _loadErrorText = null;
      _inlineErrorText = null;
    });
    try {
      final content = await widget.sourceService.loadEditableActiveSource();
      if (!mounted) {
        return;
      }
      _controller.loadText(content);
      setState(() {
        _initialContent = content;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _loadErrorText = _loadFailedText('$e');
      });
    }
  }

  Future<void> _saveSource() async {
    if (_saving || _loading || !_hasChanges) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _inlineErrorText = null;
    });
    try {
      final content = _controller.text;
      await widget.sourceService.saveEditedActiveSource(content);
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _initialContent = content;
      });
      await showHazukiPrompt(context, _saveSuccessText);
    } catch (e) {
      if (!mounted) {
        return;
      }
      final message = _saveFailedText('$e');
      setState(() {
        _saving = false;
        _inlineErrorText = message;
      });
      await showHazukiPrompt(context, message, isError: true);
    }
  }

  Widget _buildLoadingState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 14),
          Text(_loadingText),
        ],
      ),
    );
  }

  Widget _buildFatalErrorState(BuildContext context, String message) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.code_off_rounded, size: 34, color: colorScheme.error),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _loadSource,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(_retryLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: hazukiFrostedAppBar(
          context: context,
          title: Text(_pageTitle),
          actions: [
            TextButton(
              onPressed: !_loading && !_saving && _hasChanges
                  ? _saveSource
                  : null,
              child: _saving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  : Text(_saveLabel),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: HazukiSettingsPageBody(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: _loading
                ? _buildLoadingState(context)
                : _loadErrorText != null
                ? _buildFatalErrorState(context, _loadErrorText!)
                : SourceEditorContent(
                    strings: _strings,
                    controller: _controller,
                    saving: _saving,
                    inlineErrorText: _inlineErrorText,
                    onSaveRequested: _saveSource,
                  ),
          ),
        ),
      ),
    );
  }
}

Future<bool> showComicSourceRestoreDialog(
  BuildContext context, {
  required SourceRuntimeGateway sourceService,
}) {
  return showSourceEditorRestoreDialog(context, sourceService: sourceService);
}
