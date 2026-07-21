import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AiInsightsResult {
  const AiInsightsResult({required this.text, required this.generatedAt});
  final String text;
  final DateTime generatedAt;
  Map<String, String> toJson() => {
    'text': text,
    'generatedAt': generatedAt.toIso8601String(),
  };
  factory AiInsightsResult.fromJson(Map<String, dynamic> json) =>
      AiInsightsResult(
        text: json['text']?.toString() ?? '',
        generatedAt:
            DateTime.tryParse(json['generatedAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}

class AiInsightsCacheStore {
  AiInsightsCacheStore(this._storage);
  // A prompt-format change must not keep showing yesterday's cached coaching
  // response after an app update.
  static const _key = 'ai_insights_cache_v2';
  final FlutterSecureStorage _storage;
  Future<AiInsightsResult?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    try {
      return AiInsightsResult.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } on FormatException {
      return null;
    }
  }

  Future<void> save(AiInsightsResult result) =>
      _storage.write(key: _key, value: jsonEncode(result.toJson()));
  Future<void> clear() => _storage.delete(key: _key);
}
