import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/l10n.dart';
import '../../services/hazuki_source_service.dart';
import '../../widgets/widgets.dart';
import 'source_editor/source_editor_content.dart';
import 'source_editor/source_editor_controller.dart';
import 'source_editor/source_editor_restore_dialog.dart';

class ComicSourceEditorPage extends StatefulWidget {
  const ComicSourceEditorPage({super.key});

  @override
  State<ComicSourceEditorPage> createState() => _ComicSourceEditorPageState();
}

class _ComicSourceEditorPageState extends State<ComicSourceEditorPage> {
  final _controller = SourceCodeEditingController();
  final _editorScrollController = ScrollController();
  final _lineNumberScrollController = ScrollController();

  String _initialContent = '';
  String? _loadErrorText;
  String? _inlineErrorText;
  bool _loading = true;
  bool _saving = false;

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
    _editorScrollController.addListener(_syncLineNumberScrollOffset);
    _loadSource();
  }

  @override
  void dispose() {
    _editorScrollController.removeListener(_syncLineNumberScrollOffset);
    _controller.dispose();
    _editorScrollController.dispose();
    _lineNumberScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSource() async {
    setState(() {
      _loading = true;
      _loadErrorText = null;
      _inlineErrorText = null;
    });
    try {
      final content = await HazukiSourceService.instance.loadEditableJmSource();
      if (!mounted) {
        return;
      }
      _controller.setSyntaxHighlightEnabled(false);
      _controller.value = TextEditingValue(
        text: content,
        selection: TextSelection.collapsed(offset: content.length),
      );
      setState(() {
        _initialContent = content;
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _controller.scheduleSyntaxHighlightEnable();
        _syncLineNumberScrollOffset();
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
      await HazukiSourceService.instance.saveEditedJmSource(content);
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

  void _syncLineNumberScrollOffset() {
    if (!_editorScrollController.hasClients ||
        !_lineNumberScrollController.hasClients) {
      return;
    }
    final maxOffset = _lineNumberScrollController.position.maxScrollExtent;
    final target = _editorScrollController.offset.clamp(0.0, maxOffset);
    if ((_lineNumberScrollController.offset - target).abs() < 0.5) {
      return;
    }
    _lineNumberScrollController.jumpTo(target);
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
            ListenableBuilder(
              listenable: _controller,
              builder: (context, _) {
                final saveEnabled = !_loading && !_saving && _hasChanges;
                return TextButton(
                  onPressed: saveEnabled ? _saveSource : null,
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
                );
              },
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: AnimatedSwitcher(
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
                  editorScrollController: _editorScrollController,
                  lineNumberScrollController: _lineNumberScrollController,
                  saving: _saving,
                  inlineErrorText: _inlineErrorText,
                ),
        ),
      ),
    );
  }
}

Future<bool> showComicSourceRestoreDialog(BuildContext context) {
  return showSourceEditorRestoreDialog(context);
}
