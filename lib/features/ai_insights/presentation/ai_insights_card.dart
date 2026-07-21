import 'package:flutter/material.dart';
import 'package:opennutritracker/core/presentation/widgets/voice_input_button.dart';
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
        Text(_result!.text, maxLines: 2, overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Future<void> _showFullInsight(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) =>
        _CoachDialog(initialReview: _result!.text, onRefresh: _refresh),
  );
}

class _CoachDialog extends StatefulWidget {
  const _CoachDialog({required this.initialReview, required this.onRefresh});

  final String initialReview;
  final Future<void> Function() onRefresh;

  @override
  State<_CoachDialog> createState() => _CoachDialogState();
}

class _CoachDialogState extends State<_CoachDialog> {
  final _question = TextEditingController();
  final _messages = <_CoachMessage>[];
  bool _asking = false;

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final question = _question.text.trim();
    if (question.isEmpty || _asking) return;
    setState(() {
      _asking = true;
      _messages.add(_CoachMessage(question, isUser: true));
      _question.clear();
    });
    try {
      final answer = await locator<AiInsightsService>().answerQuestion(
        question,
      );
      if (mounted) {
        setState(() => _messages.add(_CoachMessage(answer, isUser: false)));
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
            content: Text('Could not answer that question. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Row(
      children: [
        const Expanded(child: Text('CalT coach')),
        IconButton(
          tooltip: 'Refresh today\'s review',
          onPressed: () async {
            await widget.onRefresh();
            if (context.mounted) Navigator.pop(context);
          },
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    content: SizedBox(
      width: 460,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.initialReview),
          const Divider(height: 28),
          const Text(
            'Ask about today\'s meals',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          if (_messages.isNotEmpty) ...[
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _messages.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, index) {
                  final message = _messages[index];
                  return Align(
                    alignment: message.isUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: message.isUser
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(message.text),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: _question,
            minLines: 1,
            maxLines: 3,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _ask(),
            decoration: InputDecoration(
              hintText: 'Ask CalT about your meals…',
              border: const OutlineInputBorder(),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  VoiceInputButton(controller: _question),
                  IconButton(
                    tooltip: 'Send question',
                    onPressed: _asking ? null : _ask,
                    icon: _asking
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  );
}

class _CoachMessage {
  const _CoachMessage(this.text, {required this.isUser});
  final String text;
  final bool isUser;
}
