part of '../../hazuki_source_service.dart';

extension _JsBridgeSupport on HazukiSourceService {
  dynamic _handleJsMessageForHandle(
    SourceRuntimeHandle handle,
    dynamic message,
  ) {
    if (message is! Map) {
      return null;
    }

    final map = Map<String, dynamic>.from(message);
    final method = map['method']?.toString();
    dynamic result;

    switch (method) {
      case 'http':
        result = _handleHttpRequestForHandle(handle, map);
        break;
      case 'cookie':
        result = _handleCookieOperationForHandle(handle, map);
        break;
      case 'load_data':
        result = handle.facade.loadSourceData(
          map['key']?.toString() ?? '',
          map['data_key']?.toString() ?? '',
        );
        break;
      case 'save_data':
        result = handle.facade.saveSourceData(
          map['key']?.toString() ?? '',
          map['data_key']?.toString() ?? '',
          map['data'],
        );
        break;
      case 'delete_data':
        result = handle.facade.deleteSourceData(
          map['key']?.toString() ?? '',
          map['data_key']?.toString() ?? '',
        );
        break;
      case 'load_setting':
        result = handle.facade.loadSourceSetting(
          map['key']?.toString() ?? '',
          map['setting_key']?.toString() ?? '',
        );
        break;
      case 'isLogged':
        result = handle.facade.loadAccountDataSync() != null;
        break;
      case 'delay':
        final ms = map['time'] is num ? (map['time'] as num).toInt() : 0;
        result = Future<void>.delayed(Duration(milliseconds: ms));
        break;
      case 'random':
        result = _handleRandom(map);
        break;
      case 'uuid':
        result = _createUuid();
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
        handle.facade.addApplicationLog(
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
        handle.runtime.engine?.port.sendPort.send(null);
      });
    }
    return result;
  }

  Future<Map<String, dynamic>> _handleHttpRequestForHandle(
    SourceRuntimeHandle handle,
    Map<String, dynamic> request,
  ) => handle.facade.httpGateway.sendJsHttpRequest(request);

  void _configureDioCookieBridge() {
    facade.httpGateway.configureCookieBridge();
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

  String _createUuid() {
    final random = math.Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    String hexByte(int value) => value.toRadixString(16).padLeft(2, '0');
    final hex = bytes.map(hexByte).join();
    return [
      hex.substring(0, 8),
      hex.substring(8, 12),
      hex.substring(12, 16),
      hex.substring(16, 20),
      hex.substring(20),
    ].join('-');
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
            : utf8.decode(jsToBytes(value));
      case 'base64':
        return isEncode
            ? base64Encode(jsToBytes(value))
            : base64Decode((value ?? '').toString());
      case 'md5':
        return Uint8List.fromList(md5.convert(jsToBytes(value)).bytes);
      case 'sha1':
        return Uint8List.fromList(sha1.convert(jsToBytes(value)).bytes);
      case 'sha256':
        return Uint8List.fromList(sha256.convert(jsToBytes(value)).bytes);
      case 'sha512':
        return Uint8List.fromList(sha512.convert(jsToBytes(value)).bytes);
      case 'hmac':
        final keyBytes = jsToBytes(request['key']);
        final valueBytes = jsToBytes(value);
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
        final key = jsToBytes(request['key']);
        final bytes = jsToBytes(value);
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
}
