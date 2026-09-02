import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AiInsightsResult {
  const AiInsightsResult({
    required this.text,
    required this.generatedAt,
    this.summary,
  });
  final String text;
  final DateTime generatedAt;
  /// A short, natural-language one-line takeaway (e.g. "Eating well today,
  /// could use more protein") — genuinely written by the model as its own
  /// output, not derived by truncating [text] client-side. Null for
  /// entries generated before this field existed, or on the rare response
  /// that didn't include one; callers should have a fallback.
  final String? summary;
  Map<String, String> toJson() => {
    'text': text,
    'generatedAt': generatedAt.toIso8601String(),
    'summary': ?summary,
  };
  factory AiInsightsResult.fromJson(Map<String, dynamic> json) =>
      AiInsightsResult(
        text: json['text']?.toString() ?? '',
        generatedAt:
            DateTime.tryParse(json['generatedAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        summary: json['summary']?.toString(),
      );
}

class AiInsightsCacheStore {
  AiInsightsCacheStore(this._storage);
  // A prompt-format change must not keep showing yesterday's cached coaching
  // response after an app update. v3 adds the one-line `summary` field.
  static const _key = 'ai_insights_cache_v3';
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
