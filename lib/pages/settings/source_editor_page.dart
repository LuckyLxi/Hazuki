part of '../../main.dart';

class ComicSourceEditorPage extends StatefulWidget {
  const ComicSourceEditorPage({super.key});

  @override
  State<ComicSourceEditorPage> createState() => _ComicSourceEditorPageState();
}

class _ComicSourceEditorPageState extends State<ComicSourceEditorPage> {
  final _controller = _SourceCodeEditingController();
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
  String get _fileBadge => 'jm.js';
  String get _hintText => _strings.sourceEditorHint;
  String get _saveSuccessText => _strings.sourceEditorSaved;
  String _loadFailedText(Object error) => _strings.sourceEditorLoadFailed(error);
  String _saveFailedText(Object error) => _strings.sourceEditorSaveFailed(error);

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
      _controller.value = TextEditingValue(
        text: content,
        selection: TextSelection.collapsed(offset: content.length),
      );
      setState(() {
        _initialContent = content;
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
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

  String _buildLineNumberText() {
    final lineCount = '\n'.allMatches(_controller.text).length + 1;
    return List<String>.generate(lineCount, (index) => '${index + 1}').join('\n');
  }

  double _measureEditorWidth(TextStyle style) {
    final lines = _controller.text.split('\n');
    final longestLine = lines.isEmpty
        ? ''
        : lines.reduce(
            (value, element) => element.length > value.length ? element : value,
          );
    final painter = TextPainter(
      text: TextSpan(text: longestLine.isEmpty ? ' ' : longestLine, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return painter.width + 40;
  }

  Widget _buildNoticeCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _hintText,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onPrimaryContainer,
                height: 1.42,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineErrorCard(BuildContext context, String message) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onErrorContainer,
                height: 1.42,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
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
              Icon(
                Icons.code_off_rounded,
                size: 34,
                color: colorScheme.error,
              ),
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

  Widget _buildEditorBody(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final editorStyle = theme.textTheme.bodyMedium?.copyWith(
          fontFamily: 'monospace',
          fontSize: 13.5,
          height: 1.5,
          letterSpacing: 0.1,
        ) ??
        const TextStyle(
          fontFamily: 'monospace',
          fontSize: 13.5,
          height: 1.5,
        );
    final lineNumberStyle = editorStyle.copyWith(
      color: colorScheme.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final lineCount = '\n'.allMatches(_controller.text).length + 1;
    final gutterWidth = 22 + (lineCount.toString().length * 10.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _buildFileBadge(context),
              const Spacer(),
              Text(
                _strings.sourceEditorLineCount(lineCount),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildNoticeCard(context),
          if (_inlineErrorText != null) ...[
            const SizedBox(height: 12),
            _buildInlineErrorCard(context, _inlineErrorText!),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.32),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.52),
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final editorWidth = math.max(
                    constraints.maxWidth - gutterWidth,
                    _measureEditorWidth(editorStyle),
                  );
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: gutterWidth + editorWidth,
                        height: constraints.maxHeight,
                        child: Row(
                          children: [
                            Container(
                              width: gutterWidth,
                              height: constraints.maxHeight,
                              padding: const EdgeInsets.fromLTRB(0, 14, 8, 14),
                              color: colorScheme.surfaceContainerHigh.withValues(
                                alpha: 0.72,
                              ),
                              alignment: Alignment.topRight,
                              child: SingleChildScrollView(
                                controller: _lineNumberScrollController,
                                physics: const NeverScrollableScrollPhysics(),
                                child: Text(
                                  _buildLineNumberText(),
                                  textAlign: TextAlign.right,
                                  style: lineNumberStyle,
                                ),
                              ),
                            ),
                            Container(
                              width: editorWidth,
                              height: constraints.maxHeight,
                              padding: const EdgeInsets.fromLTRB(0, 6, 0, 6),
                              child: Scrollbar(
                                controller: _editorScrollController,
                                thumbVisibility: true,
                                child: TextField(
                                  controller: _controller,
                                  scrollController: _editorScrollController,
                                  enabled: !_saving,
                                  expands: true,
                                  minLines: null,
                                  maxLines: null,
                                  keyboardType: TextInputType.multiline,
                                  textCapitalization: TextCapitalization.none,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  smartDashesType: SmartDashesType.disabled,
                                  smartQuotesType: SmartQuotesType.disabled,
                                  style: editorStyle.copyWith(
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                                  cursorColor: colorScheme.primary,
                                  decoration: InputDecoration(
                                    isCollapsed: true,
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.fromLTRB(
                                      14,
                                      8,
                                      18,
                                      8,
                                    ),
                                  ),
                                  onChanged: (_) {
                                    if (mounted) {
                                      setState(() {});
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileBadge(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.javascript_rounded, size: 16, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            _fileBadge,
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final saveEnabled = !_loading && !_saving && _hasChanges;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: hazukiFrostedAppBar(
          context: context,
          title: Text(_pageTitle),
          actions: [
            TextButton(
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
              : _buildEditorBody(context),
        ),
      ),
    );
  }
}

Future<bool> showComicSourceRestoreDialog(BuildContext context) async {
  final strings = l10n(context);
  var phase = _ComicSourceRestoreDialogPhase.confirm;
  var progress = 0.0;
  var indeterminate = true;

  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierLabel: strings.dialogBarrierLabel,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final theme = Theme.of(dialogContext);
          final colorScheme = theme.colorScheme;
          final textTheme = theme.textTheme;

          Widget buildConfirmContent() {
            return Column(
              key: const ValueKey<String>('restore-confirm'),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.restore_rounded,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.advancedRestoreSourceLabel,
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            strings.sourceEditorRestoreConfirmContent,
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                OverflowBar(
                  alignment: MainAxisAlignment.end,
                  spacing: 10,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: Text(strings.commonCancel),
                    ),
                    FilledButton(
                      onPressed: () async {
                        setDialogState(() {
                          phase = _ComicSourceRestoreDialogPhase.downloading;
                          progress = 0;
                          indeterminate = true;
                        });

                        final ok = await HazukiSourceService.instance
                            .downloadJmSourceAndReload(
                              onProgress: (received, total) {
                                if (!dialogContext.mounted) {
                                  return;
                                }
                                setDialogState(() {
                                  if (total > 0) {
                                    indeterminate = false;
                                    progress = (received / total).clamp(0.0, 1.0);
                                  } else {
                                    indeterminate = true;
                                  }
                                });
                              },
                            );

                        if (!dialogContext.mounted) {
                          return;
                        }

                        Navigator.of(dialogContext).pop(ok);
                        if (!ok && context.mounted) {
                          unawaited(
                            showHazukiPrompt(
                              context,
                              strings.sourceEditorRestoreFailed,
                              isError: true,
                            ),
                          );
                        }
                      },
                      child: Text(strings.commonConfirm),
                    ),
                  ],
                ),
              ],
            );
          }

          Widget buildDownloadingContent() {
            final progressText = indeterminate
                ? strings.sourceUpdateDownloading
                : strings.sourceEditorRestoreDownloadingProgress(
                    (progress * 100).toStringAsFixed(0),
                  );
            return Column(
              key: const ValueKey<String>('restore-downloading'),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        value: indeterminate ? null : progress,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        strings.sourceEditorRestoringTitle,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: indeterminate ? null : progress,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  progressText,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            );
          }

          final canDismiss = phase == _ComicSourceRestoreDialogPhase.confirm;

          return PopScope(
            canPop: canDismiss,
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: canDismiss
                        ? () => Navigator.of(dialogContext).pop(false)
                        : null,
                    child: AnimatedBuilder(
                      animation: animation,
                      builder: (context, child) {
                        final transitionProgress = Curves.easeOutCubic
                            .transform(animation.value);
                        final blurProgress = const Interval(
                          0.0,
                          0.82,
                          curve: Curves.easeOutCubic,
                        ).transform(animation.value);
                        final sigma = 6 + (16 * blurProgress);
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            ColoredBox(
                              color: Colors.black.withValues(
                                alpha: 0.22 * transitionProgress,
                              ),
                            ),
                            ClipRect(
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: sigma,
                                  sigmaY: sigma,
                                ),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        colorScheme.surface.withValues(
                                          alpha: 0.07 * transitionProgress,
                                        ),
                                        colorScheme.surface.withValues(
                                          alpha: 0.14 * transitionProgress,
                                        ),
                                        colorScheme.surfaceContainerHighest
                                            .withValues(
                                              alpha:
                                                  0.20 * transitionProgress,
                                            ),
                                      ],
                                    ),
                                  ),
                                  child: child,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                SafeArea(
                  minimum: const EdgeInsets.all(16),
                  child: Center(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {},
                      child: Material(
                        type: MaterialType.transparency,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeInOutCubic,
                          width: phase == _ComicSourceRestoreDialogPhase.confirm
                              ? 360
                              : 320,
                          padding: phase == _ComicSourceRestoreDialogPhase.confirm
                              ? const EdgeInsets.fromLTRB(20, 20, 20, 18)
                              : const EdgeInsets.fromLTRB(20, 16, 20, 16),
                          decoration: BoxDecoration(
                            color: colorScheme.surface.withValues(alpha: 0.96),
                            borderRadius: BorderRadius.circular(
                              phase == _ComicSourceRestoreDialogPhase.confirm
                                  ? 30
                                  : 22,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.18),
                                blurRadius: 26,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SizeTransition(
                                  sizeFactor: animation,
                                  axisAlignment: -1,
                                  child: child,
                                ),
                              );
                            },
                            child: phase == _ComicSourceRestoreDialogPhase.confirm
                                ? buildConfirmContent()
                                : buildDownloadingContent(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
    transitionBuilder:
        (dialogContext, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.03),
                end: Offset.zero,
              ).animate(curved),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
                child: child,
              ),
            ),
          );
        },
  );

  return result == true;
}

enum _ComicSourceRestoreDialogPhase { confirm, downloading }

class _SourceCodeEditingController extends TextEditingController {
  static const Set<String> _keywords = {
    'async',
    'await',
    'break',
    'case',
    'catch',
    'class',
    'const',
    'continue',
    'default',
    'delete',
    'else',
    'export',
    'extends',
    'false',
    'finally',
    'for',
    'from',
    'function',
    'if',
    'import',
    'in',
    'instanceof',
    'let',
    'new',
    'null',
    'of',
    'return',
    'static',
    'super',
    'switch',
    'this',
    'throw',
    'true',
    'try',
    'typeof',
    'undefined',
    'var',
    'while',
    'yield',
  };

  static final RegExp _tokenPattern = RegExp(
    r"""//.*?$|/\*[\s\S]*?\*/|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|`(?:\\.|[\s\S])*?`|\b(?:async|await|break|case|catch|class|const|continue|default|delete|else|export|extends|false|finally|for|from|function|if|import|in|instanceof|let|new|null|of|return|static|super|switch|this|throw|true|try|typeof|undefined|var|while|yield)\b|\b\d+(?:\.\d+)?\b""",
    multiLine: true,
  );

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ?? const TextStyle();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final stringStyle = baseStyle.copyWith(
      color: theme.brightness == Brightness.dark
          ? const Color(0xFFE6B673)
          : const Color(0xFF9A5B00),
    );
    final numberStyle = baseStyle.copyWith(
      color: theme.brightness == Brightness.dark
          ? const Color(0xFF8ED1A5)
          : const Color(0xFF1B7F46),
      fontWeight: FontWeight.w600,
    );
    final commentStyle = baseStyle.copyWith(
      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.82),
      fontStyle: FontStyle.italic,
    );
    final keywordStyle = baseStyle.copyWith(
      color: colorScheme.primary,
      fontWeight: FontWeight.w800,
    );

    final children = <InlineSpan>[];
    var start = 0;
    for (final match in _tokenPattern.allMatches(text)) {
      if (match.start > start) {
        children.add(
          TextSpan(
            text: text.substring(start, match.start),
            style: baseStyle,
          ),
        );
      }
      final token = match.group(0) ?? '';
      children.add(
        TextSpan(
          text: token,
          style: _styleForToken(
            token,
            baseStyle: baseStyle,
            keywordStyle: keywordStyle,
            stringStyle: stringStyle,
            numberStyle: numberStyle,
            commentStyle: commentStyle,
          ),
        ),
      );
      start = match.end;
    }
    if (start < text.length) {
      children.add(TextSpan(text: text.substring(start), style: baseStyle));
    }
    return TextSpan(style: baseStyle, children: children);
  }

  TextStyle _styleForToken(
    String token, {
    required TextStyle baseStyle,
    required TextStyle keywordStyle,
    required TextStyle stringStyle,
    required TextStyle numberStyle,
    required TextStyle commentStyle,
  }) {
    if (token.startsWith('//') || token.startsWith('/*')) {
      return commentStyle;
    }
    if (token.startsWith('"') || token.startsWith("'") || token.startsWith('`')) {
      return stringStyle;
    }
    if (_keywords.contains(token)) {
      return keywordStyle;
    }
    if (RegExp(r'^\d+(?:\.\d+)?$').hasMatch(token)) {
      return numberStyle;
    }
    return baseStyle;
  }
}
