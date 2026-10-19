import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/l10n.dart';
import '../../services/source/account/source_browser_authorization.dart';
import '../../services/source/account/source_login_interaction.dart';
import 'source_account_dialogs.dart';
import 'source_authorization_browser.dart';
import 'source_login_interaction_text.dart';
import 'source_login_dialog_controller.dart';

Future<Object?> showSourceBrowserAuthorization(
  BuildContext context,
  Map<String, dynamic> request,
  SourceLoginCancellation cancellation, {
  SourceAuthorizationBrowser Function()? browserFactory,
  SourceLoginDialogController? dialogController,
}) async {
  cancellation.check();
  final session = SourceBrowserAuthorizationSession(
    SourceBrowserAuthorizationOptions.parse(request),
    cancellation,
  );
  // Install an error handler before platform preparation or route creation.
  final outcome = session.result.then<(Map<String, Object>?, Object?)>(
    (value) => (value, null),
    onError: (Object error) => (null, error),
  );
  SourceAuthorizationBrowser? browser;
  Future<void>? preparing;
  var returningResult = false;
  try {
    browser = (browserFactory ?? createSourceAuthorizationBrowser)();
    if (session.options.cookieScopes.isNotEmpty) {
      if (browser is! SourceAuthorizationCookieBrowser) {
        throw const SourceBrowserAuthorizationException(
          'login_browser_cookie_unavailable',
        );
      }
      final cookieBrowser = browser as SourceAuthorizationCookieBrowser;
      session.readCookies = () =>
          cookieBrowser.readCookies(session.options.cookieScopes);
    }
    preparing = browser.prepare(session);
    // Errors are rendered by the dialog; this handler prevents an early error
    // between creating the future and mounting FutureBuilder.
    unawaited(preparing.catchError((Object _) {}));
    if (!context.mounted) throw const SourceLoginCancelled();
    final preparedBrowser = browser;
    Widget buildStep(ValueChanged<Object?>? finish) =>
        _BrowserAuthorizationDialog(
          session: session,
          browser: preparedBrowser,
          preparing: preparing!,
          sourceName: request['sourceName']?.toString() ?? '',
          onComplete: finish,
        );
    if (dialogController == null) {
      await showHomeAnimatedDialog<Object>(context, child: buildStep(null));
    } else {
      await dialogController.present(buildStep, cancellation);
    }
    if (session.isActive) cancellation.cancel();
    final (value, error) = await outcome;
    cancellation.check();
    if (error != null) throw error;
    returningResult = true;
    return value;
  } on SourceLoginCancelled {
    rethrow;
  } on SourceBrowserAuthorizationException {
    rethrow;
  } catch (_) {
    throw const SourceBrowserAuthorizationException(
      'login_browser_unavailable',
    );
  } finally {
    // A cancelled preparation may complete late; release its resources too.
    if (preparing != null) {
      try {
        await preparing;
      } catch (_) {}
    }
    try {
      await browser?.close();
    } catch (_) {
      if (returningResult) {
        throw const SourceBrowserAuthorizationException(
          'login_browser_cleanup_failed',
        );
      }
    } finally {
      session.dispose();
    }
  }
}

class _BrowserAuthorizationDialog extends StatefulWidget {
  const _BrowserAuthorizationDialog({
    required this.session,
    required this.browser,
    required this.preparing,
    required this.sourceName,
    this.onComplete,
  });
  final SourceBrowserAuthorizationSession session;
  final SourceAuthorizationBrowser browser;
  final Future<void> preparing;
  final String sourceName;
  final ValueChanged<Object?>? onComplete;
  @override
  State<_BrowserAuthorizationDialog> createState() =>
      _BrowserAuthorizationDialogState();
}

class _BrowserAuthorizationDialogState
    extends State<_BrowserAuthorizationDialog> {
  ModalRoute<Object?>? _route;
  bool _ready = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_changed);
    unawaited(
      widget.preparing.then((_) {
        if (mounted && widget.session.isActive) setState(() => _ready = true);
      }, onError: (Object _) {}),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
    if (!widget.session.isActive) _changed();
  }

  void _changed() {
    if (!mounted) return;
    if (!widget.session.isActive && !_finished) {
      _finished = true;
      scheduleMicrotask(() {
        if (widget.onComplete != null) {
          widget.onComplete!(true);
          return;
        }
        final route = _route;
        if (!mounted || route == null || !route.isActive) return;
        if (route.isCurrent) {
          Navigator.pop(context, true);
        } else {
          Navigator.of(context).removeRoute(route);
        }
      });
    }
    setState(() {});
  }

  @override
  void dispose() {
    widget.session.removeListener(_changed);
    if (!_finished) widget.session.cancellation.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final size = MediaQuery.sizeOf(context);
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && !_finished) widget.session.cancellation.cancel();
      },
      child: SourceLoginStepContent(
        embedded: widget.onComplete != null,
        width: math.min(808, size.width - 80),
        backgroundColor: homeDialogBackgroundColor(context),
        title: Text(
          loginInteractionText(
            context,
            widget.session.options.title ?? strings.sourceBrowserAuthorization,
          ),
        ),
        content: SizedBox(
          width: math.min(760, size.width - 80),
          height: math.max(
            0,
            math.min(
              620,
              size.height - MediaQuery.viewInsetsOf(context).bottom - 220,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.sourceName.isNotEmpty) Text(widget.sourceName),
              Text(
                widget.session.origin ?? widget.session.options.url.origin,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              if (widget.session.missingCookies)
                Text(strings.sourceBrowserCookiesMissing),
              Expanded(
                child: FutureBuilder<void>(
                  future: widget.preparing,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      final code =
                          snapshot.error is SourceBrowserAuthorizationException
                          ? (snapshot.error
                                    as SourceBrowserAuthorizationException)
                                .code
                          : '';
                      final windows = code == 'login_browser_install_webview2';
                      final android = code == 'login_browser_update_webview';
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              windows
                                  ? strings.sourceBrowserInstallWebView2
                                  : android
                                  ? strings.sourceBrowserUpdateWebView
                                  : strings.sourceBrowserUnavailable,
                            ),
                            if (windows || android)
                              TextButton(
                                onPressed: () async {
                                  try {
                                    await launchUrl(
                                      Uri.parse(
                                        windows
                                            ? 'https://developer.microsoft.com/microsoft-edge/webview2/'
                                            : 'https://play.google.com/store/apps/details?id=com.google.android.webview',
                                      ),
                                      mode: LaunchMode.externalApplication,
                                    );
                                  } catch (_) {}
                                },
                                child: Text(strings.sourceBrowserOpenHelp),
                              ),
                          ],
                        ),
                      );
                    }
                    if (!_ready || !widget.session.isActive) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        widget.browser.build(context),
                        if (widget.session.loading)
                          const Align(
                            alignment: Alignment.topCenter,
                            child: LinearProgressIndicator(),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (widget.session.options.manual && _ready)
            TextButton(
              onPressed: widget.session.completing
                  ? null
                  : () => widget.session.complete(),
              child: Text(strings.sourceBrowserCompleteLogin),
            ),
          TextButton(
            onPressed: widget.session.cancellation.cancel,
            child: Text(strings.commonCancel),
          ),
        ],
      ),
    );
  }
}
