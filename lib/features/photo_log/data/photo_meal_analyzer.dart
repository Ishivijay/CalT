import 'dart:typed_data';

import 'package:opennutritracker/features/ai_provider/data/ai_provider_config_store.dart';
import 'package:opennutritracker/features/ai_provider/data/http_llm_providers.dart';
import 'package:opennutritracker/features/ai_provider/domain/llm_provider.dart';
import 'package:opennutritracker/features/photo_log/domain/ai_photo_meal_item.dart';

class PhotoMealAnalyzer {
  PhotoMealAnalyzer(this._configStore, this._providerFactory);
  final AiProviderConfigStore _configStore;
  final LlmProviderFactory _providerFactory;

  Future<AiPhotoMealAnalysis> analyze(Uint8List image, {String hint = ''}) async {
    final config = await _configStore.read();
    if (!config.isConfigured) throw const LlmException('No AI provider configured.');
    final reply = await _providerFactory.create(config).sendVisionPrompt(
      imageBytes: image,
      promptText: _prompt(hint),
    );
    final json = reply.json;
    final rawItems = json?['items'];
    if (json == null || rawItems is! List) {
      throw const LlmException('The AI response was not a valid meal estimate. Try again.');
    }
    final items = rawItems.whereType<Map>().map(_itemFromJson).whereType<AiPhotoMealItem>().toList();
    if (items.isEmpty) throw const LlmException('No foods could be identified. Try another photo or add a hint.');
    return AiPhotoMealAnalysis(items: items, notes: json['notes']?.toString() ?? '');
  }

  AiPhotoMealItem? _itemFromJson(Map raw) {
    final json = Map<String, dynamic>.from(raw);
    final name = json['name']?.toString().trim() ?? '';
    final grams = _number(json['estimated_grams']);
    if (name.isEmpty || grams <= 0) return null;
    final confidence = AiEstimateConfidence.values.firstWhere(
      (value) => value.name == json['confidence']?.toString().toLowerCase(),
      orElse: () => AiEstimateConfidence.low,
    );
    return AiPhotoMealItem(
      name: name, grams: grams, kcal: _number(json['kcal']), proteinG: _number(json['protein_g']),
      carbsG: _number(json['carbs_g']), fatG: _number(json['fat_g']), confidence: confidence,
    );
  }

  double _number(dynamic value) => value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '') ?? 0;

  String _prompt(String hint) => '''Analyze this meal photograph. Return ONLY one JSON object in exactly this shape:
{"items":[{"name":"string","estimated_grams":0,"kcal":0,"protein_g":0,"carbs_g":0,"fat_g":0,"confidence":"low|medium|high"}],"notes":"string"}
Estimate each visible edible item separately. Numbers must be non-negative. Do not diagnose health conditions or give medical advice.${hint.trim().isEmpty ? '' : '\nUser context: ${hint.trim()}'}''';
}
