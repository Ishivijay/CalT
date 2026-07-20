import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:opennutritracker/features/ai_provider/data/llm_response_parser.dart';
import 'package:opennutritracker/features/ai_provider/domain/ai_provider_config.dart';
import 'package:opennutritracker/features/ai_provider/domain/llm_provider.dart';

class LlmProviderFactory {
  const LlmProviderFactory(this._client);
  final http.Client _client;

  LlmProvider create(AiProviderConfig config) {
    if (!config.isConfigured) throw const LlmException('Configure an AI provider first.');
    return switch (config.provider) {
      AiProviderKind.openAi => _OpenAiProvider(_client, config),
      AiProviderKind.anthropic => _AnthropicProvider(_client, config),
      AiProviderKind.gemini => _GeminiProvider(_client, config),
      AiProviderKind.customOpenAi => _OpenAiProvider(_client, config, custom: true),
    };
  }
}

abstract class _Provider implements LlmProvider {
  _Provider(this.client, this.config);
  final http.Client client;
  final AiProviderConfig config;

  Future<Map<String, dynamic>> post(Uri uri, Map<String, String> headers, Object body) async {
    final reply = await client.post(uri, headers: headers, body: jsonEncode(body)).timeout(const Duration(seconds: 45));
    if (reply.statusCode < 200 || reply.statusCode >= 300) {
      // Do not reveal provider body: it can include sensitive gateway details.
      throw LlmException('AI provider returned HTTP ${reply.statusCode}.');
    }
    try {
      return Map<String, dynamic>.from(jsonDecode(reply.body) as Map);
    } on FormatException {
      throw const LlmException('The AI provider returned invalid JSON.');
    }
  }

  LlmResponse result(String text) => LlmResponse(rawText: text, json: parseJsonObject(text));

  String textAt(Map<String, dynamic> response, List<Object> path) {
    dynamic node = response;
    for (final part in path) {
      if (part is int) {
        if (node is! List || node.length <= part) break;
        node = node[part];
      } else {
        if (node is! Map) break;
        node = node[part];
      }
    }
    if (node is! String || node.trim().isEmpty) throw const LlmException('The AI provider returned an empty response.');
    return node;
  }

  String imageData(Uint8List bytes) => base64Encode(bytes);
}

class _OpenAiProvider extends _Provider {
  _OpenAiProvider(super.client, super.config, {this.custom = false});
  final bool custom;

  Uri get _endpoint {
    if (!custom) return Uri.parse('https://api.openai.com/v1/chat/completions');
    final base = config.baseUrl?.trim();
    if (base == null || base.isEmpty) throw const LlmException('A base URL is required for a custom provider.');
    return Uri.parse(base.endsWith('/') ? '${base}chat/completions' : '$base/chat/completions');
  }

  Map<String, String> get _headers => {'Content-Type': 'application/json', 'Authorization': 'Bearer ${config.apiKey}'};

  @override
  Future<LlmResponse> sendTextPrompt(String prompt) => _send([{'role': 'user', 'content': prompt}]);

  @override
  Future<LlmResponse> sendVisionPrompt({required Uint8List imageBytes, required String promptText}) => _send([
        {'role': 'user', 'content': [
          {'type': 'text', 'text': promptText},
          {'type': 'image_url', 'image_url': {'url': 'data:image/jpeg;base64,${imageData(imageBytes)}'}},
        ]},
      ]);

  Future<LlmResponse> _send(List<Map<String, dynamic>> messages) async {
    final reply = await post(_endpoint, _headers, {'model': config.modelId, 'messages': messages});
    return result(textAt(reply, const ['choices', 0, 'message', 'content']));
  }
}

class _AnthropicProvider extends _Provider {
  _AnthropicProvider(super.client, super.config);
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'x-api-key': config.apiKey,
    'anthropic-version': '2023-06-01',
  };

  @override
  Future<LlmResponse> sendTextPrompt(String prompt) => _send([{'type': 'text', 'text': prompt}]);

  @override
  Future<LlmResponse> sendVisionPrompt({required Uint8List imageBytes, required String promptText}) => _send([
    {'type': 'text', 'text': promptText},
    {'type': 'image', 'source': {'type': 'base64', 'media_type': 'image/jpeg', 'data': imageData(imageBytes)}},
  ]);

  Future<LlmResponse> _send(List<Map<String, dynamic>> content) async {
    final reply = await post(Uri.parse('https://api.anthropic.com/v1/messages'), _headers, {
      'model': config.modelId,
      'max_tokens': 1200,
      'messages': [{'role': 'user', 'content': content}],
    });
    return result(textAt(reply, const ['content', 0, 'text']));
  }
}

class _GeminiProvider extends _Provider {
  _GeminiProvider(super.client, super.config);
  Uri get _endpoint => Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/${config.modelId}:generateContent?key=${Uri.encodeQueryComponent(config.apiKey)}');

  @override
  Future<LlmResponse> sendTextPrompt(String prompt) => _send([{'text': prompt}]);

  @override
  Future<LlmResponse> sendVisionPrompt({required Uint8List imageBytes, required String promptText}) => _send([
    {'text': promptText},
    {'inline_data': {'mime_type': 'image/jpeg', 'data': imageData(imageBytes)}},
  ]);

  Future<LlmResponse> _send(List<Map<String, dynamic>> parts) async {
    final reply = await post(_endpoint, const {'Content-Type': 'application/json'}, {'contents': [{'parts': parts}]});
    return result(textAt(reply, const ['candidates', 0, 'content', 'parts', 0, 'text']));
  }
}
