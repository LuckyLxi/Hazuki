import 'source_local_script_bridge.dart';
import '../../../models/source_meta.dart';
import '../models/source_script_execution.dart';

import '../account/source_browser_authorization.dart';
import '../account/source_external_authorization.dart';
import 'source_runtime_facade.dart';
import 'source_runtime_handle.dart';
import 'source_cookie_store.dart';
import 'source_html_bridge.dart';
import '../plugins/source_plugin_models.dart';
import '../plugins/source_plugin_localization.dart';
import '../interaction/source_ui_service.dart';
import '../interaction/source_dialog_model.dart';

/// Handles the JavaScript host bridge and its cookie operations.
class SourceJsBridgeCookieCapability {
  SourceJsBridgeCookieCapability({
    required SourceRuntimeHandle Function() activeHandle,
  }) : _activeHandle = activeHandle;

  final SourceRuntimeHandle Function() _activeHandle;
  final _local = SourceLocalScriptBridge();

  Future<dynamic> handleCookieOperationForHandle(
    SourceRuntimeHandleView handle,
    Map<String, dynamic> request,
  ) => handle.cookieStore.handleOperation(request);

  String? buildCookieHeader(String url) =>
      _activeHandle().cookieStore.buildHeader(url);

  String? buildCookieHeaderForHandle(
    SourceRuntimeHandleView handle,
    String url,
  ) => handle.cookieStore.buildHeader(url);

  Future<void> saveCookiesFromHeadersForHandle(
    SourceRuntimeHandleView handle,
    String url,
    Map<String, List<String>> headers,
  ) => handle.cookieStore.saveFromHeaders(url, headers);

  dynamic handleJsMessageForHandle(
    SourceRuntimeHandle handle,
    dynamic message, {
    SourceHtmlBridge? htmlBridge,
    SourceScriptExecution? execution,
    String? runtimeId,
    SourceMeta? Function()? sourceMeta,
  }) {
    if (message is! Map) return null;
    final map = Map<String, dynamic>.from(message);
    final method = map['method']?.toString();
    if (method != null && method.startsWith('ui_')) {
      if (execution == null ||
          runtimeId == null ||
          handle.isDisposalRequested) {
        if (method == 'ui_available') return false;
        throw StateError('plugin_ui_unavailable');
      }
      if (method == 'ui_browser' || method == 'ui_browser_result') {
        final browserSession = method == 'ui_browser_result'
            ? SourceUiService.instance.browserSession(
                map['id']?.toString() ?? '',
                execution,
                runtimeId,
              )
            : null;
        final options = SourceBrowserAuthorizationOptions.parse(
          browserSession?.browserRequest ?? dialogMap(map['options']),
        );
        return SourceUiService.instance
            .runBrowserAuthorization(
              () => SourceUiService.instance.handle(
                map,
                execution,
                runtimeId,
                sourceMeta?.call()?.name ??
                    handle.runtime.sourceMeta?.name ??
                    handle.sourceKey,
              ),
              execution: execution,
              runtimeId: runtimeId,
              timeout: options.timeout,
              interactionScope: browserSession?.scope,
            )
            .then(
              (value) => _importBrowserResponse(
                handle,
                options,
                value as Map,
                () {
                  if (handle.isDisposalRequested) {
                    throw StateError('plugin_runtime_disposed');
                  }
                  handle.loginCancellation?.check();
                  SourceUiService.instance.checkExecution(execution, runtimeId);
                },
              ),
            );
      }
      return SourceUiService.instance.handle(
        map,
        execution,
        runtimeId,
        sourceMeta?.call()?.name ??
            handle.runtime.sourceMeta?.name ??
            handle.sourceKey,
        translation:
            sourceMeta?.call()?.translation ??
            handle.runtime.sourceMeta?.translation ??
            const {},
      );
    }
    dynamic result;
    if (handle.isDisposed) throw StateError('plugin_runtime_disposed');
    handle.loginCancellation?.check();
    switch (method) {
      case 'login_external_prepare':
      case 'login_external_close':
        final cancellation = handle.loginCancellation;
        if (cancellation == null || handle.loginPresenter == null) {
          throw StateError('login_interaction_required');
        }
        final broker = SourceExternalAuthorizationBroker.instance;
        result = method == 'login_external_prepare'
            ? broker.prepare(
                Map<String, dynamic>.from(map['request'] as Map),
                cancellation,
              )
            : broker.close(map['id']?.toString() ?? '', cancellation);
        break;
      case 'login_interaction':
        final cancellation = handle.loginCancellation;
        final present = handle.loginPresenter;
        if (cancellation == null || present == null) {
          throw StateError('login_interaction_required');
        }
        cancellation.check();
        final request = Map<String, dynamic>.from(map['request'] as Map);
        if (request['type'] == 'externalAuthorization') {
          SourceExternalAuthorizationBroker.instance.require(
            request['id']?.toString() ?? '',
            cancellation,
          );
          request['sourceName'] =
              handle.runtime.sourceMeta?.name ?? handle.sourceKey;
        }
        if (request['type'] == 'browserAuthorization') {
          SourceBrowserAuthorizationOptions.parse(request);
          request['sourceName'] =
              handle.runtime.sourceMeta?.name ?? handle.sourceKey;
        }
        final count = request['pointCount'];
        if (count != null && (count is! int || count < 1 || count > 32)) {
          throw const FormatException('login_invalid_point_count');
        }
        final presented = request['type'] == 'browserAuthorization'
            ? SourceUiService.instance.runBrowserAuthorization(
                () => present(request, cancellation),
                execution: execution,
                runtimeId: runtimeId,
                timeout: SourceBrowserAuthorizationOptions.parse(
                  request,
                ).timeout,
              )
            : present(request, cancellation);
        result = presented.then((value) {
          cancellation.check();
          if (request['type'] != 'browserAuthorization' || value is! Map) {
            return value;
          }
          return _importBrowserResponse(
            handle,
            SourceBrowserAuthorizationOptions.parse(request),
            value,
            cancellation.check,
          );
        });
        break;
      case 'html':
        result = (htmlBridge ?? handle.htmlBridge).handleOperation(map);
        break;
      case 'secret_get':
      case 'secret_set':
      case 'secret_delete':
        final key = map['secret_key']?.toString() ?? '';
        if (!RegExp(r'^[a-zA-Z0-9_.-]{1,64}$').hasMatch(key)) {
          throw const SourcePluginException('plugin_invalid_secret_key');
        }
        final scoped = 'hazuki_plugin_secret_v1:${handle.sourceKey}:$key';
        result = method == 'secret_get'
            ? handle.secureStorage.read(scoped)
            : method == 'secret_delete'
            ? handle.secureStorage.delete(scoped)
            : handle.secureStorage.write(scoped, map['value'].toString());
        break;
      case 'save_setting':
        result = handle.facade.saveSourceSetting(
          _requireScopedSourceKey(handle, map),
          map['setting_key']?.toString() ?? '',
          map['value'],
        );
        break;
      case 'http':
        if (execution != null && runtimeId != null) {
          SourceUiService.instance.checkExecution(execution, runtimeId);
        }
        result = handle.facade.httpGateway.sendJsHttpRequest(
          map,
          execution: execution,
          runtimeId: runtimeId,
          checkActive: () {
            handle.loginCancellation?.check();
            if (execution != null && runtimeId != null) {
              SourceUiService.instance.checkExecution(execution, runtimeId);
            }
          },
        );
        break;
      case 'cookie':
        result = handleCookieOperationForHandle(handle, map);
        break;
      case 'load_data':
        result = handle.facade.loadSourceData(
          _requireScopedSourceKey(handle, map),
          map['data_key']?.toString() ?? '',
        );
        break;
      case 'save_data':
        result = handle.facade.saveSourceData(
          _requireScopedSourceKey(handle, map),
          map['data_key']?.toString() ?? '',
          map['data'],
        );
        break;
      case 'delete_data':
        result = handle.facade.deleteSourceData(
          _requireScopedSourceKey(handle, map),
          map['data_key']?.toString() ?? '',
        );
        break;
      case 'load_setting':
        final settingKey = map['setting_key']?.toString() ?? '';
        result = handle.session.loadSourceSetting(
          sourceKey: _requireScopedSourceKey(handle, map),
          settingKey: settingKey,
          sourceMeta: sourceMeta != null
              ? sourceMeta()
              : handle.runtime.sourceMeta,
          settingsDefaults: map.containsKey('default_value')
              ? {settingKey: map['default_value']}
              : null,
        );
        break;
      case 'isLogged':
        _requireScopedSourceKey(handle, map);
        result = handle.facade.isLogged;
        break;
      case 'delay':
        final ms = map['time'] is num ? (map['time'] as num).toInt() : 0;
        result = Future<void>.delayed(Duration(milliseconds: ms));
        break;
      case 'random':
        result = _local.random(map);
        break;
      case 'uuid':
        result = _local.uuid();
        break;
      case 'convert':
        result = _local.convert(map);
        break;
      case 'getLocale':
        result = sourcePluginLocaleTag(handle.session.prefs);
        break;
      case 'getPlatform':
        result = _local.handle(map);
        break;
      case 'log':
        // Foreground login may hold a complete authorization callback. Never
        // forward plugin console data from this transient runtime to diagnostics.
        if (handle.loginCancellation != null) break;
        handle.facade.addApplicationLog(
          level: map['level']?.toString() ?? 'info',
          title: map['title']?.toString() ?? 'Application',
          content: map['content'],
          source: 'js_console',
        );
        break;
      default:
        throw UnsupportedError('Unsupported JS bridge method: $method');
    }
    return result;
  }

  Future<Map<String, dynamic>> _importBrowserResponse(
    SourceRuntimeHandle handle,
    SourceBrowserAuthorizationOptions options,
    Map value,
    void Function() checkActive,
  ) async {
    checkActive();
    final response = Map<String, dynamic>.from(value);
    final cookies = response.remove('_cookies');
    final userAgent = response.remove('_userAgent');
    if (response['status'] == 'completed' && options.cookieScopes.isNotEmpty) {
      if (cookies is! List) {
        throw StateError('login_browser_cookie_missing');
      }
      if (userAgent is! String ||
          userAgent.trim().isEmpty ||
          userAgent.contains(RegExp(r'[\r\n]'))) {
        throw const SourceBrowserAuthorizationException(
          'login_browser_user_agent_unavailable',
        );
      }
      final userAgents = handle.session.loadBrowserUserAgents();
      for (final scope in options.cookieScopes) {
        final selected = cookies
            .whereType<Map>()
            .where(
              (c) =>
                  c['scopeUrl'] == scope.url && scope.names.contains(c['name']),
            )
            .map((c) => SourceCookie.fromMap(Map<String, dynamic>.from(c)))
            .where(
              (c) =>
                  c.matches(Uri.parse(scope.url)) &&
                  !c.isExpired(DateTime.now().millisecondsSinceEpoch),
            )
            .toList();
        if (scope.names.any((n) => !selected.any((c) => c.name == n))) {
          throw StateError('login_browser_cookie_missing');
        }
        await handle.cookieStore.set(scope.url, selected);
        userAgents[Uri.parse(scope.url).origin] = userAgent;
        checkActive();
      }
      await handle.session.saveBrowserUserAgents(userAgents);
      checkActive();
    }
    return response;
  }

  void configureDioCookieBridge([SourceRuntimeHandle? handle]) =>
      (handle ?? _activeHandle()).facade.httpGateway.configureCookieBridge();

  String _requireScopedSourceKey(
    SourceRuntimeHandle handle,
    Map<String, dynamic> request,
  ) {
    final requested = request['key']?.toString().trim() ?? '';
    if (requested != handle.sourceKey) {
      throw StateError(
        'source_bridge_scope_violation:${handle.sourceKey}:$requested',
      );
    }
    return handle.sourceKey;
  }
}
