import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/translation/translation_failure.dart';

void main() {
  DioException httpError(
    int status, {
    dynamic data,
    String? retryAfter,
    DioExceptionType type = DioExceptionType.badResponse,
  }) {
    final options = RequestOptions(path: '/test');
    return DioException(
      requestOptions: options,
      type: type,
      response: Response<dynamic>(
        requestOptions: options,
        statusCode: status,
        data: data,
        headers: Headers.fromMap({
          if (retryAfter != null) 'retry-after': [retryAfter],
        }),
      ),
    );
  }

  test('recognizes cancellation before HTTP auth or quota errors', () {
    for (final status in [401, 429, 500]) {
      expect(
        TranslationFailure.from(
          httpError(status, type: DioExceptionType.cancel),
        ).kind,
        TranslationFailureKind.cancelled,
      );
    }
  });

  test('classifies HTTP status and quota response bodies', () {
    for (final status in [401, 403]) {
      expect(
        TranslationFailure.from(httpError(status)).kind,
        TranslationFailureKind.unauthorized,
      );
    }
    expect(
      TranslationFailure.from(httpError(402)).kind,
      TranslationFailureKind.quotaExceeded,
    );
    for (final data in [
      'QUOTA exceeded',
      {
        'error': {'code': 'insufficient_quota'},
      },
      'Billing required',
    ]) {
      expect(
        TranslationFailure.from(httpError(429, data: data)).kind,
        TranslationFailureKind.quotaExceeded,
      );
    }
    expect(
      TranslationFailure.from(httpError(429, data: 'Too many requests')).kind,
      TranslationFailureKind.rateLimited,
    );
    for (final status in [500, 502, 503]) {
      expect(
        TranslationFailure.from(httpError(status)).kind,
        TranslationFailureKind.server,
      );
    }
    expect(
      TranslationFailure.from(httpError(400)).kind,
      TranslationFailureKind.unknown,
    );
  });

  test('retains Retry-After seconds and supports HTTP dates', () {
    expect(
      TranslationFailure.from(httpError(429, retryAfter: '8')).retryAfter,
      const Duration(seconds: 8),
    );
    expect(
      TranslationFailure.from(httpError(429, retryAfter: 'invalid')).retryAfter,
      isNull,
    );
    expect(TranslationFailure.from(httpError(429)).retryAfter, isNull);
    final date = HttpDate.format(
      DateTime.now().toUtc().add(const Duration(seconds: 30)),
    );
    final delay = TranslationFailure.from(
      httpError(429, retryAfter: date),
    ).retryAfter!;
    expect(delay.inSeconds, inInclusiveRange(28, 30));
    expect(
      TranslationFailure.from(httpError(429, retryAfter: '-2')).retryAfter,
      Duration.zero,
    );
  });

  test(
    'classifies connection errors, timeouts, malformed JSON, and unknown errors',
    () {
      for (final type in [
        DioExceptionType.connectionError,
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        expect(
          TranslationFailure.from(
            DioException(requestOptions: RequestOptions(), type: type),
          ).kind,
          TranslationFailureKind.network,
        );
      }
      expect(
        TranslationFailure.from(const FormatException('bad JSON')).kind,
        TranslationFailureKind.badResponse,
      );
      expect(
        TranslationFailure.from(
          DioException(
            requestOptions: RequestOptions(),
            error: const FormatException('bad JSON'),
          ),
        ).kind,
        TranslationFailureKind.badResponse,
      );
      expect(
        TranslationFailure.from(StateError('unknown')).kind,
        TranslationFailureKind.unknown,
      );
      const classified = TranslationFailure(TranslationFailureKind.network);
      expect(TranslationFailure.from(classified), same(classified));
    },
  );

  test('does not include raw credentials or request data in failure text', () {
    final error = DioException(
      requestOptions: RequestOptions(
        headers: {'Authorization': 'Bearer secret'},
        data: 'private-image',
      ),
      message: 'secret private-image',
    );
    final failure = TranslationFailure.from(error);
    expect(failure.toString(), 'TranslationFailure(unknown)');
  });
}
