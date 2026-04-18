part of '../hazuki_source_service.dart';

extension _JsBridgeSupport on HazukiSourceService {
  dynamic _handleJsMessage(dynamic message) {
    if (message is! Map) {
      return null;
    }

    final map = Map<String, dynamic>.from(message);
    final method = map['method']?.toString();
    dynamic result;

    switch (method) {
      case 'http':
        result = _handleHttpRequest(map);
        break;
      case 'cookie':
        result = _handleCookieOperation(map);
        break;
      case 'load_data':
        result = _loadSourceData(
          map['key']?.toString() ?? '',
          map['data_key']?.toString() ?? '',
        );
        break;
      case 'save_data':
        result = _saveSourceData(
          map['key']?.toString() ?? '',
          map['data_key']?.toString() ?? '',
          map['data'],
        );
        break;
      case 'delete_data':
        result = _deleteSourceData(
          map['key']?.toString() ?? '',
          map['data_key']?.toString() ?? '',
        );
        break;
      case 'load_setting':
        result = _loadSourceSetting(
          map['key']?.toString() ?? '',
          map['setting_key']?.toString() ?? '',
        );
        break;
      case 'isLogged':
        result = _loadAccountDataSync() != null;
        break;
      case 'delay':
        final ms = map['time'] is num ? (map['time'] as num).toInt() : 0;
        result = Future<void>.delayed(Duration(milliseconds: ms));
        break;
      case 'random':
        result = _handleRandom(map);
        break;
      case 'convert':
        result = _handleConvert(map);
        break;
      case 'getLocale':
        result = 'zh_CN';
        break;
      case 'getPlatform':
        final os = Platform.operatingSystem;
        result = (os == 'android' || os == 'ios') ? os : 'android';
        break;
      case 'log':
        addApplicationLog(
          level: map['level']?.toString() ?? 'info',
          title: map['title']?.toString() ?? 'Application',
          content: map['content'],
          source: 'js_console',
        );
        result = null;
        break;
      default:
        throw UnsupportedError('鏆傛湭瀹炵幇锟?JS 鏂规硶: $method');
    }

    if (result is Future) {
      result = result.whenComplete(() {
        _engine?.port.sendPort.send(null);
      });
    }
    return result;
  }

  Future<Map<String, dynamic>> _handleHttpRequest(
    Map<String, dynamic> request,
  ) async {
    Response<dynamic>? response;
    String? error;
    final startedAt = DateTime.now();

    final method = (request['http_method']?.toString() ?? 'GET').toUpperCase();
    var url = request['url']?.toString() ?? '';

    if (method == 'GET' && url.isNotEmpty) {
      final connector = url.contains('?') ? '&' : '?';
      url =
          '$url${connector}_hazuki_nocache=${DateTime.now().millisecondsSinceEpoch}';
    }

    final headers = Map<String, dynamic>.from(request['headers'] as Map? ?? {});
    final bytes = request['bytes'] == true;
    final data = request['data'];

    try {
      response = await _dio.request<dynamic>(
        url,
        data: data,
        options: Options(
          method: method,
          responseType: bytes ? ResponseType.bytes : ResponseType.plain,
          headers: headers,
          extra: {
            'skipNetworkDebugLog': true,
            if (bytes) 'hazukiLogCategory': 'image_download',
          },
        ),
      );
    } catch (e) {
      error = e.toString();
    } finally {
      final responseHeadersForLog = <String, dynamic>{};
      response?.headers.forEach((name, values) {
        responseHeadersForLog[name] = values.join(',');
      });
      _appendNetworkLog(
        method: method,
        url: url,
        statusCode: response?.statusCode,
        error: error,
        startedAt: startedAt,
        source: 'js_http',
        category: bytes ? 'image_download' : 'js_http',
        requestHeaders: Map<String, dynamic>.from(headers),
        requestData: data,
        responseHeaders: responseHeadersForLog,
        responseBody: response?.data,
      );
    }

    final responseHeaders = <String, String>{};
    response?.headers.forEach((name, values) {
      responseHeaders[name] = values.join(',');
    });

    return {
      'status': response?.statusCode,
      'headers': responseHeaders,
      'body': response?.data,
      'error': error,
    };
  }

  void _configureDioCookieBridge() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.extra['hazukiStartedAt'] = DateTime.now();
          final cookieHeader = _buildCookieHeader(options.uri.toString());
          if (cookieHeader != null && cookieHeader.isNotEmpty) {
            final existing = options.headers['cookie'];
            if (existing is String && existing.trim().isNotEmpty) {
              options.headers['cookie'] = '$existing; $cookieHeader';
            } else {
              options.headers['cookie'] = cookieHeader;
            }
          }
          handler.next(options);
        },
        onResponse: (response, handler) async {
          final requestUrl = response.requestOptions.uri.toString();
          await _saveCookiesFromHeaders(requestUrl, response.headers.map);

          final skipLog =
              response.requestOptions.extra['skipNetworkDebugLog'] == true;
          if (!skipLog) {
            final startedAt =
                response.requestOptions.extra['hazukiStartedAt'] is DateTime
                ? response.requestOptions.extra['hazukiStartedAt'] as DateTime
                : DateTime.now();
            final responseHeadersForLog = <String, dynamic>{};
            response.headers.forEach((name, values) {
              responseHeadersForLog[name] = values.join(',');
            });
            _appendNetworkLog(
              method: response.requestOptions.method,
              url: requestUrl,
              statusCode: response.statusCode,
              error: null,
              startedAt: startedAt,
              source: 'dio_direct',
              category: response.requestOptions.extra['hazukiLogCategory']
                  ?.toString(),
              requestHeaders: Map<String, dynamic>.from(
                response.requestOptions.headers,
              ),
              requestData: response.requestOptions.data,
              responseHeaders: responseHeadersForLog,
              responseBody: response.data,
            );
          }
          handler.next(response);
        },
        onError: (error, handler) {
          final options = error.requestOptions;
          final skipLog = options.extra['skipNetworkDebugLog'] == true;
          if (!skipLog) {
            final startedAt = options.extra['hazukiStartedAt'] is DateTime
                ? options.extra['hazukiStartedAt'] as DateTime
                : DateTime.now();
            final responseHeadersForLog = <String, dynamic>{};
            final response = error.response;
            response?.headers.forEach((name, values) {
              responseHeadersForLog[name] = values.join(',');
            });
            _appendNetworkLog(
              method: options.method,
              url: options.uri.toString(),
              statusCode: response?.statusCode,
              error: error.toString(),
              startedAt: startedAt,
              source: 'dio_direct',
              category: options.extra['hazukiLogCategory']?.toString(),
              requestHeaders: Map<String, dynamic>.from(options.headers),
              requestData: options.data,
              responseHeaders: responseHeadersForLog,
              responseBody: response?.data,
            );
          }
          handler.next(error);
        },
      ),
    );

    _dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        return HttpClient();
      },
    );
  }

  dynamic _handleRandom(Map<String, dynamic> request) {
    final min = request['min'];
    final max = request['max'];
    final type = request['type']?.toString() ?? 'int';
    final minNum = min is num ? min : 0;
    final maxNum = max is num ? max : 1;
    if (type == 'double') {
      return minNum + (maxNum - minNum) * DateTime.now().microsecond / 1000000;
    }
    final range = (maxNum - minNum).toInt();
    if (range <= 0) {
      return minNum.toInt();
    }
    return minNum.toInt() + (DateTime.now().microsecond % range);
  }

  dynamic _handleConvert(Map<String, dynamic> request) {
    final type = request['type']?.toString() ?? '';
    final isEncode = request['isEncode'] == true;
    final isString = request['isString'] == true;
    final value = request['value'];

    switch (type) {
      case 'utf8':
        return isEncode
            ? utf8.encode((value ?? '').toString())
            : utf8.decode(_toBytes(value));
      case 'base64':
        return isEncode
            ? base64Encode(_toBytes(value))
            : base64Decode((value ?? '').toString());
      case 'md5':
        return Uint8List.fromList(md5.convert(_toBytes(value)).bytes);
      case 'sha1':
        return Uint8List.fromList(sha1.convert(_toBytes(value)).bytes);
      case 'sha256':
        return Uint8List.fromList(sha256.convert(_toBytes(value)).bytes);
      case 'sha512':
        return Uint8List.fromList(sha512.convert(_toBytes(value)).bytes);
      case 'hmac':
        final keyBytes = _toBytes(request['key']);
        final valueBytes = _toBytes(value);
        final hashType = request['hash']?.toString() ?? 'md5';
        final digest = Hmac(switch (hashType) {
          'md5' => md5,
          'sha1' => sha1,
          'sha256' => sha256,
          'sha512' => sha512,
          _ => md5,
        }, keyBytes).convert(valueBytes);
        if (isString) {
          return digest.toString();
        }
        return Uint8List.fromList(digest.bytes);
      case 'aes-ecb':
        final key = _toBytes(request['key']);
        final bytes = _toBytes(value);
        final cipher = ECBBlockCipher(AESEngine())
          ..init(isEncode, KeyParameter(key));
        final result = Uint8List(bytes.length);
        var offset = 0;
        while (offset < bytes.length) {
          offset += cipher.processBlock(bytes, offset, result, offset);
        }
        return result;
      case 'gbk':
      case 'aes-cbc':
      case 'aes-cfb':
      case 'aes-ofb':
      case 'rsa':
        throw UnsupportedError('convert 鏆備笉鏀寔: $type');
      default:
        return value;
    }
  }

  Uint8List _toBytes(dynamic value) {
    if (value is Uint8List) {
      return value;
    }
    if (value is List<int>) {
      return Uint8List.fromList(value);
    }
    if (value is List) {
      return Uint8List.fromList(value.map((e) => (e as num).toInt()).toList());
    }
    if (value is String) {
      return Uint8List.fromList(utf8.encode(value));
    }
    return Uint8List(0);
  }

  bool _asBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      return value == 'true' || value == '1';
    }
    return false;
  }

  int? _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }
}
