import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/debug/debug_log_compactor.dart';

void main() {
  const compactor = DebugLogCompactor();

  test('keeps useful network headers and redacts credentials', () {
    final compacted = compactor.compactNetworkHeaders({
      'Content-Type': 'application/json',
      'Authorization': 'Bearer secret',
      'Cookie': 'session=secret',
      'Set-Cookie': 'session=secret',
      'X-Internal-Secret': 'hidden',
    });

    expect(compacted, {
      'Content-Type': 'application/json',
      'Authorization': '[redacted]',
      'Cookie': '[redacted]',
      'Set-Cookie': '[redacted]',
    });
  });

  test('compacts nested values by string, item, and depth limits', () {
    final compacted =
        compactor.compactGenericLogValue(
              {
                'long': '123456789',
                'nested': {
                  'deeper': {'secret': true},
                },
                'extra': true,
              },
              maxStringLength: 4,
              maxItems: 2,
              maxDepth: 2,
            )
            as Map<String, dynamic>;

    expect(compacted['long'], '1234... [omitted 5 chars]');
    expect(compacted['nested'], {'deeper': '[map omitted]'});
    expect(compacted['__truncated__'], '+1 keys');
  });

  test('reader compaction keeps verbose state only for failures', () {
    final content = {
      'sessionId': 'session',
      'trigger': 'page_changed',
      'comicId': 'comic',
      'listPixels': 120.0,
      'unrelated': 'discarded',
    };

    final info =
        compactor.compactReaderLogContent(
              content,
              source: 'reader',
              level: 'info',
            )
            as Map;
    final error =
        compactor.compactReaderLogContent(
              content,
              source: 'reader',
              level: 'error',
            )
            as Map;

    expect(info, {'sessionId': 'session', 'trigger': 'page_changed'});
    expect(error['comicId'], 'comic');
    expect(error['listPixels'], 120.0);
    expect(error.containsKey('unrelated'), isFalse);
  });

  test('network payloads cap collection size', () {
    final compacted =
        compactor.compactNetworkPayload(
              List<int>.generate(10, (index) => index),
              keep: 20,
            )
            as List;

    expect(compacted.take(8), List<int>.generate(8, (index) => index));
    expect(compacted.last, '[+2 items]');
  });
}
