import 'dart:async';
import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../services/source/account/source_external_authorization.dart';
import '../../services/source/account/source_login_interaction.dart';
import 'source_account_dialogs.dart';
import 'source_login_interaction_text.dart';
import 'source_login_dialog_controller.dart';

Future<Object?> showSourceExternalAuthorization(
  BuildContext context,
  Map<String, dynamic> request,
  SourceLoginCancellation cancellation, {
  SourceLoginDialogController? dialogController,
}) async {
  final session = SourceExternalAuthorizationBroker.instance.require(
    request['id'] as String,
    cancellation,
  );
  final outcome = session
      .launch(request['url'] as String)
      .then<(Map<String, Object>?, Object?)>(
        (value) => (value, null),
        onError: (Object error) => (null, error),
      );
  if (dialogController == null) {
    await showHomeAnimatedDialog<void>(
      context,
      child: _ExternalAuthorizationDialog(request, cancellation, outcome),
    );
  } else {
    await dialogController.present(
      (finish) => _ExternalAuthorizationDialog(
        request,
        cancellation,
        outcome,
        onComplete: finish,
      ),
      cancellation,
    );
  }
  final (value, error) = await outcome;
  cancellation.check();
  if (error != null) throw error;
  return value;
}

class _ExternalAuthorizationDialog extends StatefulWidget {
  const _ExternalAuthorizationDialog(
    this.request,
    this.cancellation,
    this.outcome, {
    this.onComplete,
  });
  final Map<String, dynamic> request;
  final SourceLoginCancellation cancellation;
  final Future<(Map<String, Object>?, Object?)> outcome;
  final ValueChanged<Object?>? onComplete;
  @override
  State<_ExternalAuthorizationDialog> createState() =>
      _ExternalAuthorizationDialogState();
}

class _ExternalAuthorizationDialogState
    extends State<_ExternalAuthorizationDialog> {
  bool _finished = false;
  ModalRoute<Object?>? _route;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void initState() {
    super.initState();
    unawaited(
      widget.outcome.then((_) {
        if (!mounted) return;
        _finished = true;
        if (widget.onComplete != null) {
          widget.onComplete!(true);
          return;
        }
        final route = _route;
        if (route?.isActive != true) return;
        if (route!.isCurrent) {
          Navigator.of(context).pop();
        } else {
          Navigator.of(context).removeRoute(route);
        }
      }),
    );
  }

  @override
  void dispose() {
    if (!_finished) widget.cancellation.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    onPopInvokedWithResult: (didPop, _) {
      if (didPop && !_finished) widget.cancellation.cancel();
    },
    child: SourceLoginStepContent(
      embedded: widget.onComplete != null,
      backgroundColor: homeDialogBackgroundColor(context),
      title: Text(
        loginInteractionText(
          context,
          widget.request['title'] ?? l10n(context).sourceBrowserAuthorization,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.request['sourceName']?.toString() ?? ''),
          const SizedBox(height: 16),
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(l10n(context).sourceExternalAuthorizationWaiting),
        ],
      ),
      actions: [
        TextButton(
          onPressed: widget.cancellation.cancel,
          child: Text(l10n(context).commonCancel),
        ),
      ],
    ),
  );
}
