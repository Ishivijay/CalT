import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the user's own override of CalT's coaching instructions, so
/// anyone who wants a different tone or focus than the built-in prompt can
/// have one — read by [AiInsightsService] in place of its default
/// instruction text when non-empty. The diary/profile data the prompt is
/// built around is still assembled automatically either way; this only
/// covers the "how to behave / what to return" instruction paragraph, not
/// the data injection.
class CoachPromptStore {
  CoachPromptStore(this._storage);
  static const _key = 'calt_coach_custom_prompt_v1';
  final FlutterSecureStorage _storage;

  Future<String?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.trim().isEmpty) return null;
    return raw;
  }

  Future<void> save(String prompt) => _storage.write(key: _key, value: prompt);
  Future<void> clear() => _storage.delete(key: _key);
}
