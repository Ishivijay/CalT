import 'dart:typed_data';

class LlmResponse {
  const LlmResponse({required this.rawText, this.json});
  final String rawText;
  final Map<String, dynamic>? json;
}

abstract interface class LlmProvider {
  Future<LlmResponse> sendVisionPrompt({
    required Uint8List imageBytes,
    required String promptText,
  });
  Future<LlmResponse> sendTextPrompt(String prompt);
}

class LlmException implements Exception {
  const LlmException(this.message);
  final String message;
  @override
  String toString() => message;
}
