import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:opennutritracker/features/ai_provider/domain/ai_provider_config.dart';

/// API keys never enter Hive, logs, analytics, or crash reports.
class AiProviderConfigStore {
  AiProviderConfigStore(this._storage);
  static const _key = 'ai_provider_config_v1';
  final FlutterSecureStorage _storage;

  Future<AiProviderConfig> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return AiProviderConfig.empty;
    try {
      return AiProviderConfig.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } on FormatException {
      return AiProviderConfig.empty;
    }
  }

  Future<void> save(AiProviderConfig config) => _storage.write(key: _key, value: jsonEncode(config.toJson()));
  Future<void> clear() => _storage.delete(key: _key);
}
