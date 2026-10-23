import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/network/hazuki_network_factory.dart';
import 'package:hazuki/services/translation/manga_translation_provider.dart';
import 'package:hazuki/services/translation/manga_translation_provider_factory.dart';
import 'package:hazuki/services/translation/manga_translation_settings_store.dart';
import 'package:hazuki/services/translation/providers/anthropic_provider.dart';
import 'package:hazuki/services/translation/providers/open_ai_compatible_provider.dart';
import 'package:hazuki/services/translation/translation_failure.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handle);

  final FutureOr<ResponseBody> Function(RequestOptions) handle;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handle(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(dynamic data, {int status = 200}) => ResponseBody.fromString(
  jsonEncode(data),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

Matcher _failure(TranslationFailureKind kind) =>
    isA<TranslationFailure>().having((error) => error.kind, 'kind', kind);

void main() {
  final image = TranslationImagePayload(
    jpegBytes: Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]),
    width: 1,
    height: 1,
  );
  late _Adapter adapter;
  late MangaTranslationProviderFactory factory;

  void setupClient(FutureOr<ResponseBody> Function(RequestOptions) handle) {
    adapter = _Adapter(handle);
    final dio = createHazukiDio(
      baseOptions: BaseOptions(),
      configureIoAdapter: false,
    )..httpClientAdapter = adapter;
    factory = MangaTranslationProviderFactory(dio: dio);
    addTearDown(factory.dispose);
  }

  MangaTranslationProvider provider(
    TranslationProviderPreset preset, {
    String key = 'test-key',
  }) => factory.create(
    preset,
    TranslationProviderConfiguration(
      baseUrl: 'https://proxy.example/api/v1/',
      model: 'user-selected-model',
      apiKey: key,
    ),
  );

  for (final preset in TranslationProviderPreset.values) {
    test(
      '${preset.name} lists models with preset-specific auth and preserves proxy URL paths',
      () async {
        setupClient(
          (_) => _json({
            'data': [
              {'id': 'vision-a'},
              {'id': 'vision-b'},
            ],
          }),
        );
        final client = provider(preset);
        expect(await client.listModels(), ['vision-a', 'vision-b']);
        final request = adapter.requests.single;
        expect(request.uri.toString(), 'https://proxy.example/api/v1/models');
        expect(request.method, 'GET');
        if (preset == TranslationProviderPreset.claude) {
          expect(client, isA<AnthropicProvider>());
          expect(request.headers['x-api-key'], 'test-key');
          expect(request.headers['anthropic-version'], '2023-06-01');
          expect(request.headers.containsKey('Authorization'), isFalse);
        } else {
          expect(client, isA<OpenAiCompatibleProvider>());
          expect(request.headers['Authorization'], 'Bearer test-key');
          expect(request.headers.containsKey('x-api-key'), isFalse);
        }
      },
    );

    test(
      '${preset.name} sends the specified image protocol and parses usage',
      () async {
        final isClaude = preset == TranslationProviderPreset.claude;
        setupClient(
          (_) => _json(
            isClaude
                ? {
                    'content': [
                      {'type': 'text', 'text': '{"regions":[],'},
                      {'type': 'text', 'text': '"terms":[]}'},
                    ],
                    'usage': {'input_tokens': 123, 'output_tokens': 45},
                  }
                : {
                    'choices': [
                      {
                        'message': {'content': '{"regions":[],"terms":[]}'},
                      },
                    ],
                    'usage': {'prompt_tokens': 123, 'completion_tokens': 45},
                  },
          ),
        );
        final result = await provider(
          preset,
        ).translateImage(image, 'system prompt', 'user prompt');
        expect(jsonDecode(result.text), {'regions': [], 'terms': []});
        expect(result.usage.inputTokens, 123);
        expect(result.usage.outputTokens, 45);

        final request = adapter.requests.single;
        expect(request.method, 'POST');
        final body = request.data as Map<String, dynamic>;
        expect(body['model'], 'user-selected-model');
        final messages = body['messages'] as List;
        if (isClaude) {
          expect(request.uri.path, '/api/v1/messages');
          expect(body['system'], 'system prompt');
          expect(body['max_tokens'], 4096);
          expect(messages, hasLength(1));
          expect(messages.single['role'], 'user');
          expect(messages.single['content'], [
            {
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': 'image/jpeg',
                'data': base64Encode(image.jpegBytes),
              },
            },
            {'type': 'text', 'text': 'user prompt'},
          ]);
        } else {
          expect(request.uri.path, '/api/v1/chat/completions');
          expect(messages.first, {
            'role': 'system',
            'content': 'system prompt',
          });
          expect(messages.last['role'], 'user');
          expect(messages.last['content'], [
            {'type': 'text', 'text': 'user prompt'},
            {
              'type': 'image_url',
              'image_url': {
                'url':
                    'data:image/jpeg;base64,${base64Encode(image.jpegBytes)}',
              },
            },
          ]);
          if (preset == TranslationProviderPreset.custom) {
            expect(body.containsKey('response_format'), isFalse);
          } else {
            expect(body['response_format'], {'type': 'json_object'});
          }
        }
      },
    );
  }

  for (final preset in [
    TranslationProviderPreset.openai,
    TranslationProviderPreset.claude,
  ]) {
    final isClaude = preset == TranslationProviderPreset.claude;

    test('${preset.name} defaults missing token counts to zero', () async {
      setupClient(
        (_) => _json(
          isClaude
              ? {
                  'content': [
                    {'type': 'text', 'text': '{}'},
                  ],
                }
              : {
                  'choices': [
                    {
                      'message': {'content': '{}'},
                    },
                  ],
                },
        ),
      );
      final result = await provider(
        preset,
      ).translateImage(image, 'system', 'user');
      expect(result.usage.inputTokens, 0);
      expect(result.usage.outputTokens, 0);
    });

    test(
      '${preset.name} rejects malformed model lists and translation responses',
      () async {
        dynamic response = {
          'data': [{}],
        };
        setupClient((_) => _json(response));
        final client = provider(preset);
        await expectLater(
          client.listModels(),
          throwsA(_failure(TranslationFailureKind.badResponse)),
        );
        for (final body in [
          <String, dynamic>{},
          isClaude ? {'content': []} : {'choices': []},
          isClaude
              ? {
                  'content': [
                    {'type': 'text', 'text': ''},
                  ],
                }
              : {
                  'choices': [
                    {
                      'message': {'content': ''},
                    },
                  ],
                },
          isClaude
              ? {
                  'content': [
                    {'type': 'text', 'text': 10},
                  ],
                }
              : {
                  'choices': [
                    {'message': null},
                  ],
                },
        ]) {
          response = body;
          await expectLater(
            client.translateImage(image, 'system', 'user'),
            throwsA(_failure(TranslationFailureKind.badResponse)),
          );
        }
      },
    );

    test('${preset.name} rejects invalid JSON as badResponse', () async {
      setupClient(
        (_) => ResponseBody.fromString(
          '{invalid',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );
      await expectLater(
        provider(preset).listModels(),
        throwsA(_failure(TranslationFailureKind.badResponse)),
      );
    });

    test('${preset.name} classifies HTTP and connection failures', () async {
      var status = 401;
      setupClient((options) {
        if (status == 0) {
          throw DioException.connectionError(
            requestOptions: options,
            reason: 'offline',
          );
        }
        return _json({'error': 'private response'}, status: status);
      });
      final client = provider(preset);
      for (final entry in {
        401: TranslationFailureKind.unauthorized,
        402: TranslationFailureKind.quotaExceeded,
        429: TranslationFailureKind.rateLimited,
        500: TranslationFailureKind.server,
        0: TranslationFailureKind.network,
      }.entries) {
        status = entry.key;
        await expectLater(
          client.translateImage(image, 'system', 'user'),
          throwsA(_failure(entry.value)),
        );
      }
    });

    test(
      '${preset.name} does not send requests for a cancelled token',
      () async {
        setupClient((_) => _json({}));
        final token = CancelToken()..cancel('closed');
        final client = provider(preset);
        await expectLater(
          client.listModels(cancelToken: token),
          throwsA(_failure(TranslationFailureKind.cancelled)),
        );
        await expectLater(
          client.translateImage(image, 'system', 'user', cancelToken: token),
          throwsA(_failure(TranslationFailureKind.cancelled)),
        );
        expect(adapter.requests, isEmpty);
      },
    );

    test('${preset.name} cancels an in-flight translation', () async {
      final started = Completer<void>();
      final response = Completer<ResponseBody>();
      setupClient((_) {
        started.complete();
        return response.future;
      });
      final token = CancelToken();
      final request = provider(
        preset,
      ).translateImage(image, 'system', 'user', cancelToken: token);
      final assertion = expectLater(
        request,
        throwsA(_failure(TranslationFailureKind.cancelled)),
      );
      await started.future;
      token.cancel('page left');
      await assertion;
      response.complete(_json({}));
      expect(adapter.requests, hasLength(1));
    });
  }

  test('shared transport keeps provider credentials isolated', () async {
    setupClient((_) => _json({'data': []}));
    await provider(
      TranslationProviderPreset.openai,
      key: 'openai-key',
    ).listModels();
    await provider(
      TranslationProviderPreset.claude,
      key: 'claude-key',
    ).listModels();
    await provider(
      TranslationProviderPreset.custom,
      key: 'custom-key',
    ).listModels();
    expect(adapter.requests[0].headers['Authorization'], 'Bearer openai-key');
    expect(adapter.requests[1].headers['x-api-key'], 'claude-key');
    expect(adapter.requests[1].headers.containsKey('Authorization'), isFalse);
    expect(adapter.requests[2].headers['Authorization'], 'Bearer custom-key');
    expect(adapter.requests[2].headers.containsKey('x-api-key'), isFalse);
  });
}
