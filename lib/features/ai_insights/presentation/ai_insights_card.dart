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
  AiInsightsResult? _result;
  bool _loading = true;
  bool _configured = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final config = await locator<AiProviderConfigStore>().read();
    final cached = await locator<AiInsightsService>().cachedForToday();
    if (mounted) {
      setState(() {
        _configured = config.isConfigured;
        _result = cached;
        _loading = false;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final result = await locator<AiInsightsService>().generate(force: true);
      if (mounted) {
        setState(() => _result = result);
      }
    } on LlmException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not generate insights. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.fromLTRB(16, 10, 16, 2),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _result == null ? null : () => _showFullInsight(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Icons.auto_awesome_rounded,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: _content(context)),
            if (_result != null) const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    ),
  );

  Widget _content(BuildContext context) {
    if (_loading) {
      return const LinearProgressIndicator();
    }
    if (!_configured) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CalT coach',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          TextButton(
            onPressed: () async {
              await Navigator.of(
                context,
              ).pushNamed(NavigationOptions.aiProviderSettingsRoute);
              _load();
            },
            child: const Text('Connect AI for personal coaching'),
          ),
        ],
      );
    }
    if (_result == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CalT coach',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          TextButton(
            onPressed: _refresh,
            child: const Text('Generate your personalized summary'),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CALT COACH',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: .8,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _todayLine(_result!.text),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  String _todayLine(String text) => text
      .split(RegExp(r'\r?\n'))
      .firstWhere((line) => line.trim().isNotEmpty, orElse: () => text)
      .replaceFirst(RegExp(r'^TODAY:\s*', caseSensitive: false), '')
      .trim();

  Future<void> _showFullInsight(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('CalT coach'),
      content: SingleChildScrollView(child: Text(_result!.text)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.pop(context);
            _refresh();
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
      ],
    ),
  );
}
