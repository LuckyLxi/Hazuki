import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'models/translation_models.dart';
import 'translation_failure.dart';

class TranslationImagePayload {
  const TranslationImagePayload({
    required this.jpegBytes,
    required this.width,
    required this.height,
  });

  final Uint8List jpegBytes;
  final int width;
  final int height;
}

class ProviderRawResponse {
  const ProviderRawResponse({required this.text, required this.usage});

  final String text;
  final TranslationUsage usage;
}

abstract interface class MangaTranslationProvider {
  Future<List<String>> listModels({CancelToken? cancelToken});

  Future<ProviderRawResponse> translateImage(
    TranslationImagePayload image,
    String systemPrompt,
    String userPrompt, {
    CancelToken? cancelToken,
  });
}

abstract class HttpMangaTranslationProvider
    implements MangaTranslationProvider {
  HttpMangaTranslationProvider({
    required this.dio,
    required String baseUrl,
    required this.apiKey,
    required this.model,
  }) : baseUrl = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');

  final Dio dio;
  final String baseUrl;
  final String apiKey;
  final String model;

  Map<String, String> get headers;

  Future<Map<String, dynamic>> requestJson(
    String path, {
    Map<String, dynamic>? data,
    CancelToken? cancelToken,
  }) async {
    try {
      if (cancelToken?.isCancelled ?? false) {
        throw const TranslationFailure(TranslationFailureKind.cancelled);
      }
      final response = await dio.request<Map<String, dynamic>>(
        '$baseUrl/$path',
        data: data,
        options: Options(
          method: data == null ? 'GET' : 'POST',
          headers: headers,
          contentType: Headers.jsonContentType,
          responseType: ResponseType.json,
          validateStatus: (status) =>
              status != null && status >= 200 && status < 300,
        ),
        cancelToken: cancelToken,
      );
      if (cancelToken?.isCancelled ?? false) {
        throw const TranslationFailure(TranslationFailureKind.cancelled);
      }
      final result = response.data;
      if (result == null) {
        throw const TranslationFailure(TranslationFailureKind.badResponse);
      }
      return result;
    } catch (error) {
      if (cancelToken?.isCancelled ?? false) {
        throw const TranslationFailure(TranslationFailureKind.cancelled);
      }
      throw TranslationFailure.from(error);
    }
  }

  @override
  Future<List<String>> listModels({CancelToken? cancelToken}) async {
    final response = await requestJson('models', cancelToken: cancelToken);
    try {
      return (response['data'] as List)
          .map((entry) => (entry as Map<String, dynamic>)['id'] as String)
          .toList(growable: false);
    } catch (error) {
      throw TranslationFailure.from(error);
    }
  }
}
