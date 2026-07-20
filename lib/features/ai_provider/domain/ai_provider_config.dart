enum AiProviderKind { openAi, anthropic, gemini, customOpenAi }

class AiProviderConfig {
  const AiProviderConfig({
    required this.provider,
    required this.apiKey,
    required this.modelId,
    this.baseUrl,
  });

  final AiProviderKind provider;
  final String apiKey;
  final String modelId;
  final String? baseUrl;

  bool get isConfigured => apiKey.trim().isNotEmpty && modelId.trim().isNotEmpty;

  Map<String, String> toJson() => {
        'provider': provider.name,
        'apiKey': apiKey,
        'modelId': modelId,
        if (baseUrl?.trim().isNotEmpty ?? false) 'baseUrl': baseUrl!.trim(),
      };

  factory AiProviderConfig.fromJson(Map<String, dynamic> json) => AiProviderConfig(
        provider: AiProviderKind.values.firstWhere(
          (value) => value.name == json['provider'],
          orElse: () => AiProviderKind.openAi,
        ),
        apiKey: json['apiKey']?.toString() ?? '',
        modelId: json['modelId']?.toString() ?? '',
        baseUrl: json['baseUrl']?.toString(),
      );

  static const empty = AiProviderConfig(
    provider: AiProviderKind.openAi,
    apiKey: '',
    modelId: 'gpt-4o-mini',
  );
}
