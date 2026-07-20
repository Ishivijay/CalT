import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/ai_provider/domain/ai_provider_config.dart';
import 'package:opennutritracker/features/ai_provider/presentation/ai_provider_settings_bloc.dart';

class AiProviderSettingsPage extends StatefulWidget {
  const AiProviderSettingsPage({super.key});
  @override
  State<AiProviderSettingsPage> createState() => _AiProviderSettingsPageState();
}
class _AiProviderSettingsPageState extends State<AiProviderSettingsPage> {
  final _model = TextEditingController(); final _key = TextEditingController(); final _baseUrl = TextEditingController();
  AiProviderKind _provider = AiProviderKind.openAi; bool _hideKey = true;
  late final AiProviderSettingsBloc _bloc;
  @override
  void initState() { super.initState(); _bloc = locator<AiProviderSettingsBloc>()..add(const LoadAiProviderSettings()); }
  @override
  void dispose() { _model.dispose(); _key.dispose(); _baseUrl.dispose(); _bloc.close(); super.dispose(); }
  AiProviderConfig get _config => AiProviderConfig(provider: _provider, apiKey: _key.text, modelId: _model.text, baseUrl: _baseUrl.text);
  void _set(AiProviderConfig config) { _provider = config.provider; _model.text = config.modelId; _key.text = config.apiKey; _baseUrl.text = config.baseUrl ?? ''; }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('AI Provider (BYOK)')),
    body: BlocConsumer<AiProviderSettingsBloc, AiProviderSettingsState>(
      bloc: _bloc,
      listener: (context, state) {
        if (state is AiProviderSettingsReady) {
          if (!state.isTesting) _set(state.config);
          if (state.message != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message!)));
        }
      },
      builder: (context, state) {
        if (state is AiProviderSettingsLoading) return const Center(child: CircularProgressIndicator());
        final ready = state as AiProviderSettingsReady;
        return ListView(padding: const EdgeInsets.all(20), children: [
          Text('Your key stays in encrypted device storage. Photos and prompts are sent only to the provider you choose.', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 20),
          DropdownButtonFormField<AiProviderKind>(
            value: _provider, decoration: const InputDecoration(labelText: 'Provider', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: AiProviderKind.openAi, child: Text('OpenAI')),
              DropdownMenuItem(value: AiProviderKind.anthropic, child: Text('Anthropic')),
              DropdownMenuItem(value: AiProviderKind.gemini, child: Text('Gemini')),
              DropdownMenuItem(value: AiProviderKind.customOpenAi, child: Text('Custom OpenAI-compatible')),
            ], onChanged: ready.isTesting ? null : (value) => setState(() => _provider = value!),
          ),
          const SizedBox(height: 14),
          TextField(controller: _model, enabled: !ready.isTesting, decoration: const InputDecoration(labelText: 'Model ID', hintText: 'e.g. gpt-4o-mini', border: OutlineInputBorder())),
          if (_provider == AiProviderKind.customOpenAi) ...[
            const SizedBox(height: 14),
            TextField(controller: _baseUrl, enabled: !ready.isTesting, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'Base URL', hintText: 'https://host/v1', border: OutlineInputBorder())),
          ],
          const SizedBox(height: 14),
          TextField(controller: _key, enabled: !ready.isTesting, obscureText: _hideKey, autocorrect: false, enableSuggestions: false, decoration: InputDecoration(labelText: 'API key', border: const OutlineInputBorder(), suffixIcon: IconButton(icon: Icon(_hideKey ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _hideKey = !_hideKey)))),
          const SizedBox(height: 20),
          FilledButton.icon(onPressed: ready.isTesting ? null : () => _bloc.add(TestAiProviderConnection(_config)), icon: ready.isTesting ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.wifi_tethering), label: const Text('Test connection')),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: ready.isTesting ? null : () => _bloc.add(SaveAiProviderSettings(_config)), child: const Text('Save securely')),
        ]);
      },
    ),
  );
}
