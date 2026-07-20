import 'dart:convert';

/// Handles a valid JSON object even when a model improperly wraps it in prose
/// or a Markdown code fence. Invalid replies deliberately return null.
Map<String, dynamic>? parseJsonObject(String raw) {
  final cleaned = raw.trim()
      .replaceFirst(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '')
      .replaceFirst(RegExp(r'\s*```$'), '')
      .trim();
  final start = cleaned.indexOf('{');
  final end = cleaned.lastIndexOf('}');
  if (start < 0 || end < start) return null;
  try {
    final value = jsonDecode(cleaned.substring(start, end + 1));
    return value is Map ? Map<String, dynamic>.from(value) : null;
  } on FormatException {
    return null;
  }
}
