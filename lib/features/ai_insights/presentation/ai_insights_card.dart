import 'package:flutter/material.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/ai_insights/data/ai_insights_cache_store.dart';
import 'package:opennutritracker/features/ai_insights/data/ai_insights_service.dart';
import 'package:opennutritracker/features/ai_provider/data/ai_provider_config_store.dart';
import 'package:opennutritracker/features/ai_provider/domain/llm_provider.dart';

class AiInsightsCard extends StatefulWidget {
  const AiInsightsCard({super.key});
  @override
  State<AiInsightsCard> createState() => _AiInsightsCardState();
}
class _AiInsightsCardState extends State<AiInsightsCard> {
  AiInsightsResult? _result; bool _loading = true; bool _configured = false;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final config = await locator<AiProviderConfigStore>().read();
    final cached = await locator<AiInsightsService>().cachedForToday();
    if (mounted) setState(() { _configured = config.isConfigured; _result = cached; _loading = false; });
  }
  Future<void> _refresh() async {
    setState(() => _loading = true);
    try { final result = await locator<AiInsightsService>().generate(force: true); if (mounted) setState(() => _result = result); }
    on LlmException catch (error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message))); }
    catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not generate insights. Please try again.'))); }
    finally { if (mounted) setState(() => _loading = false); }
  }
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Icon(Icons.auto_awesome_outlined), const SizedBox(width: 8), Text('AI insights', style: Theme.of(context).textTheme.titleMedium), const Spacer(), IconButton(tooltip: 'Refresh insights', onPressed: _loading || !_configured ? null : _refresh, icon: const Icon(Icons.refresh))]),
      const SizedBox(height: 8),
      if (_loading) const LinearProgressIndicator() else if (!_configured) ...[
        const Text('Connect an AI provider to receive a private summary of your logged patterns.'),
        TextButton(onPressed: () async { await Navigator.of(context).pushNamed(NavigationOptions.aiProviderSettingsRoute); _load(); }, child: const Text('Set up AI provider')),
      ] else if (_result == null) ...[
        const Text('Generate a summary of your last 7 and 30 days. Your diary is sent only to the provider you configured.'),
        TextButton(onPressed: _refresh, child: const Text('Generate insights')),
      ] else ...[
        Text(_result!.text), const SizedBox(height: 10), Text('Generated ${_format(_result!.generatedAt)} · AI-generated, not medical advice.', style: Theme.of(context).textTheme.bodySmall),
      ],
    ])),
  );
  String _format(DateTime date) => '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}
