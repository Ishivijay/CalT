import 'package:flutter/material.dart';
import 'package:opennutritracker/core/presentation/widgets/app_card.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/ai_insights/data/ai_insights_cache_store.dart';
import 'package:opennutritracker/features/ai_insights/data/ai_insights_service.dart';
import 'package:opennutritracker/features/ai_insights/data/calt_coach_chat_history_store.dart';
import 'package:opennutritracker/features/ai_insights/data/coach_prompt_store.dart';
import 'package:opennutritracker/features/ai_provider/data/ai_provider_config_store.dart';
import 'package:opennutritracker/features/ai_provider/domain/ai_provider_config.dart';
import 'package:opennutritracker/features/ai_provider/domain/llm_provider.dart';

const _exampleQuestions = <String>[
  'How can I add more protein today?',
  'Am I on track for my goal this week?',
  'What should I eat for dinner tonight?',
  'Is my sugar intake too high today?',
];

/// CalT coach's own screen: today's review, which AI provider/model is
/// active, the editable coach instructions, and the Q&A chat — all as
/// plain, readable tiles instead of unlabeled icon buttons, and all in one
/// scrollable page instead of squeezed into a bottom sheet.
class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key, this.scrollToAsk = false});

  /// When true, the screen scrolls straight to the "Ask CalT" section on
  /// open — used by the Home app bar's chat shortcut, which exists
  /// specifically to jump into asking a question rather than reading
  /// today's review first.
  final bool scrollToAsk;

  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  final _question = TextEditingController();
  final _messages = <CalTCoachChatMessage>[];
  final _askSectionKey = GlobalKey();
  final _scrollController = ScrollController();

  AiInsightsResult? _result;
  AiProviderConfig? _providerConfig;
  String _instruction = AiInsightsService.defaultReviewInstruction;
  bool _loadingInsight = true;
  bool _loadingHistory = true;
  bool _asking = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadHistory();
    if (widget.scrollToAsk) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = _askSectionKey.currentContext;
        if (context != null) {
          Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _question.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final config = await locator<AiProviderConfigStore>().read();
    final customInstruction = await locator<CoachPromptStore>().read();
    final cached = await locator<AiInsightsService>().cachedForToday();
    if (mounted) {
      setState(() {
        _providerConfig = config;
        _instruction = customInstruction ?? AiInsightsService.defaultReviewInstruction;
        _result = cached;
        _loadingInsight = false;
      });
    }
  }

  Future<void> _loadHistory() async {
    final history = await locator<CalTCoachChatHistoryStore>().read();
    if (!mounted) return;
    setState(() {
      _messages
        ..clear()
        ..addAll(history);
      _loadingHistory = false;
    });
  }

  Future<void> _saveHistory() =>
      locator<CalTCoachChatHistoryStore>().save(_messages);

  Future<void> _startNewChat() async {
    setState(() => _messages.clear());
    await _saveHistory();
  }

  Future<void> _refreshInsight() async {
    setState(() => _loadingInsight = true);
    try {
      final result = await locator<AiInsightsService>().generate(force: true);
      if (mounted) setState(() => _result = result);
    } on LlmException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Could not generate insights. Please try again.');
    } finally {
      if (mounted) setState(() => _loadingInsight = false);
    }
  }

  Future<void> _ask(String question) async {
    final trimmed = question.trim();
    if (trimmed.isEmpty || _asking) return;
    setState(() {
      _asking = true;
      _messages.add(CalTCoachChatMessage(text: trimmed, isUser: true));
      _question.clear();
    });
    await _saveHistory();
    try {
      final answer = await locator<AiInsightsService>().answerQuestion(trimmed);
      if (mounted) {
        setState(
          () => _messages.add(CalTCoachChatMessage(text: answer, isUser: false)),
        );
        await _saveHistory();
      }
    } on LlmException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Could not answer that question. Please try again.');
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openProviderSettings() async {
    await Navigator.of(context).pushNamed(NavigationOptions.aiProviderSettingsRoute);
    _load();
  }

  Future<void> _editPrompt() async {
    final controller = TextEditingController(text: _instruction);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _PromptEditorDialog(controller: controller),
    );
    controller.dispose();
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? AppPalette.dark : AppPalette.light;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('CalT Coach')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(
                Dimens.spacing16,
                Dimens.spacing12,
                Dimens.spacing16,
                Dimens.spacing8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InsightSection(
                    loading: _loadingInsight,
                    configured: _providerConfig?.isConfigured ?? false,
                    result: _result,
                    palette: palette,
                    onRefresh: _refreshInsight,
                  ),
                  const SizedBox(height: Dimens.spacing12),
                  _ProviderTile(config: _providerConfig, onTap: _openProviderSettings),
                  const SizedBox(height: Dimens.spacing12),
                  _InstructionsTile(instruction: _instruction, onTap: _editPrompt),
                  const SizedBox(height: Dimens.spacing16),
                  Text('Ask CalT', key: _askSectionKey, style: textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    'Ask about today\'s meals, your goals, or try one of these:',
                    style: textTheme.bodyMedium?.copyWith(color: palette.textMuted),
                  ),
                  const SizedBox(height: Dimens.spacing8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final q in _exampleQuestions)
                        ActionChip(
                          label: Text(q),
                          onPressed: _asking ? null : () => _ask(q),
                        ),
                    ],
                  ),
                  const SizedBox(height: Dimens.spacing16),
                  if (_messages.isNotEmpty) ...[
                    Row(
                      children: [
                        Text('Conversation', style: textTheme.titleSmall),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _startNewChat,
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('New chat'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (_loadingHistory)
                    const Center(child: CircularProgressIndicator())
                  else
                    for (final message in _messages)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Align(
                          alignment: message.isUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 330),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: message.isUser
                                    ? palette.accent.withValues(alpha: 0.16)
                                    : palette.surfaceMuted,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  message.text,
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: palette.textStrong,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  if (_asking)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: TextField(
              controller: _question,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.send,
              onSubmitted: _ask,
              decoration: InputDecoration(
                hintText: 'Ask CalT coach…',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: 'Send question',
                  onPressed: _asking ? null : () => _ask(_question.text),
                  icon: const Icon(Icons.send_rounded),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightSection extends StatelessWidget {
  const _InsightSection({
    required this.loading,
    required this.configured,
    required this.result,
    required this.palette,
    required this.onRefresh,
  });
  final bool loading;
  final bool configured;
  final AiInsightsResult? result;
  final AppPalette palette;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final accent = Theme.of(context).colorScheme.primary;

    Widget content;
    if (!configured) {
      content = Text(
        'Connect an AI provider below to get personalized reviews of today\'s meals.',
        style: textTheme.bodyMedium?.copyWith(color: palette.textMuted),
      );
    } else if (result == null && !loading) {
      content = Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.auto_awesome_rounded),
          label: const Text('Generate today\'s review'),
        ),
      );
    } else if (result == null) {
      content = const SizedBox(
        height: 24,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    } else {
      final points = AiInsightsService.bulletPoints(result!.text);
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final point in points)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 18, color: accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      point,
                      style: textTheme.bodyMedium?.copyWith(color: palette.textStrong),
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(Dimens.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Today\'s review', style: textTheme.titleSmall),
              const Spacer(),
              if (configured && !loading)
                IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  onPressed: onRefresh,
                  visualDensity: VisualDensity.compact,
                ),
              if (loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: Dimens.spacing8),
          content,
        ],
      ),
    );
  }
}

/// Shows which provider/model CalT is actually configured to use, in plain
/// text — not just a settings gear icon with nothing said about what it
/// does. Tapping it opens the BYOK setup screen.
class _ProviderTile extends StatelessWidget {
  const _ProviderTile({required this.config, required this.onTap});
  final AiProviderConfig? config;
  final VoidCallback onTap;

  static String _providerLabel(AiProviderKind kind) => switch (kind) {
    AiProviderKind.openAi => 'OpenAI',
    AiProviderKind.anthropic => 'Anthropic',
    AiProviderKind.gemini => 'Gemini',
    AiProviderKind.customOpenAi => 'Custom OpenAI-compatible',
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? AppPalette.dark : AppPalette.light;
    final textTheme = Theme.of(context).textTheme;
    final configured = config?.isConfigured ?? false;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(Icons.smart_toy_outlined, color: palette.textMuted),
          const SizedBox(width: Dimens.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI provider', style: textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  configured
                      ? '${_providerLabel(config!.provider)} · ${config!.modelId}'
                      : 'Not connected — tap to add your own API key',
                  style: textTheme.bodyMedium?.copyWith(color: palette.textMuted),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: palette.textMuted),
        ],
      ),
    );
  }
}

/// Shows the actual instruction text CalT is given — not hidden behind an
/// icon — plus an explicit line saying it's editable, since a plain "tune"
/// icon with no label gave no hint this was here at all.
class _InstructionsTile extends StatelessWidget {
  const _InstructionsTile({required this.instruction, required this.onTap});
  final String instruction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? AppPalette.dark : AppPalette.light;
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(Dimens.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 18, color: palette.textMuted),
              const SizedBox(width: 8),
              Text('Coach instructions', style: textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: Dimens.spacing8),
          Text(
            instruction,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium?.copyWith(color: palette.textStrong),
          ),
          const SizedBox(height: Dimens.spacing8),
          Text(
            'This is what CalT is told before it reviews your diary. Tap to edit it or write your own.',
            style: textTheme.labelSmall?.copyWith(color: palette.textMuted),
          ),
        ],
      ),
    );
  }
}

class _PromptEditorDialog extends StatelessWidget {
  const _PromptEditorDialog({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Coach instructions'),
    content: SizedBox(
      width: 460,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This is what CalT is told before it sees your diary. Edit it to change tone or focus — your profile and today\'s logged meals are always added automatically after this text.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              minLines: 6,
              maxLines: 12,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () {
          controller.text = AiInsightsService.defaultReviewInstruction;
        },
        child: const Text('Reset to default'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () async {
          final text = controller.text.trim();
          if (text.isEmpty || text == AiInsightsService.defaultReviewInstruction) {
            await locator<CoachPromptStore>().clear();
          } else {
            await locator<CoachPromptStore>().save(text);
          }
          if (context.mounted) Navigator.pop(context, true);
        },
        child: const Text('Save'),
      ),
    ],
  );
}
