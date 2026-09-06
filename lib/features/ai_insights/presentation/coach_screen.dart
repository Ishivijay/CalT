import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Deliberately spans the windows the coach can actually reach — today,
/// the past week, the past month, and the longer record — so the range of
/// what it can be asked is visible from the chips rather than something
/// you have to guess at.
const _exampleQuestions = <String>[
  'What should I eat for dinner tonight?',
  'How has my week been?',
  'What changed in my eating this month?',
  'Am I consistent, or do I log in bursts?',
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
    await _answer(trimmed);
  }

  /// Sends [question] and appends the reply. Split out from [_ask] because
  /// regenerating and editing re-run a question that is already in the
  /// transcript — they must not append a second copy of it.
  Future<void> _answer(String question) async {
    try {
      final answer = await locator<AiInsightsService>().answerQuestion(question);
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

  Future<void> _copyMessage(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Copied')));
  }

  /// Throws away the answer at [index] and everything after it, then asks
  /// the question above it again. Later turns were written in reply to the
  /// answer being discarded, so keeping them would leave the transcript
  /// referring to text that is no longer there.
  Future<void> _regenerate(int index) async {
    if (_asking) return;
    final question = _questionBefore(index);
    if (question == null) return;
    setState(() {
      _asking = true;
      _messages.removeRange(index, _messages.length);
    });
    await _saveHistory();
    await _answer(question);
  }

  /// Rewrites the question at [index] and re-asks it, dropping the replaced
  /// exchange and everything that followed for the same reason.
  Future<void> _editAndResend(int index) async {
    if (_asking) return;
    final edited = await showDialog<String>(
      context: context,
      builder: (context) =>
          _EditMessageDialog(initialText: _messages[index].text),
    );
    final trimmed = edited?.trim();
    if (trimmed == null || trimmed.isEmpty) return;
    setState(() {
      _asking = true;
      _messages.removeRange(index, _messages.length);
      _messages.add(CalTCoachChatMessage(text: trimmed, isUser: true));
    });
    await _saveHistory();
    await _answer(trimmed);
  }

  String? _questionBefore(int index) {
    for (var i = index - 1; i >= 0; i--) {
      if (_messages[i].isUser) return _messages[i].text;
    }
    return null;
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
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _PromptEditorDialog(initialText: _instruction),
    );
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
                    'Ask about today, this week, this month, or your habits '
                    'overall — or try one of these:',
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
                    for (final (index, message) in _messages.indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: message.isUser
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            ConstrainedBox(
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
                                  child: SelectableText(
                                    message.text,
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: palette.textStrong,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            _MessageActions(
                              palette: palette,
                              isUser: message.isUser,
                              enabled: !_asking,
                              onCopy: () => _copyMessage(message.text),
                              onEdit: message.isUser
                                  ? () => _editAndResend(index)
                                  : null,
                              // Only offer a retry where there is a question
                              // above to retry; a stray leading answer from
                              // an older transcript has nothing to re-ask.
                              onRegenerate:
                                  !message.isUser &&
                                      _questionBefore(index) != null
                                  ? () => _regenerate(index)
                                  : null,
                            ),
                          ],
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

/// The quiet row of actions under a chat bubble: copy either side, edit and
/// re-send your own question, or ask for another attempt at an answer.
/// Deliberately understated — these sit under every message, so anything
/// heavier would compete with the conversation itself.
class _MessageActions extends StatelessWidget {
  const _MessageActions({
    required this.palette,
    required this.isUser,
    required this.enabled,
    required this.onCopy,
    this.onEdit,
    this.onRegenerate,
  });

  final AppPalette palette;
  final bool isUser;
  final bool enabled;
  final VoidCallback onCopy;
  final VoidCallback? onEdit;
  final VoidCallback? onRegenerate;

  @override
  Widget build(BuildContext context) {
    Widget action(IconData icon, String tooltip, VoidCallback? onPressed) =>
        IconButton(
          icon: Icon(icon, size: 16),
          tooltip: tooltip,
          onPressed: enabled ? onPressed : null,
          color: palette.textMuted,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 34, minHeight: 30),
        );

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onEdit != null) action(Icons.edit_outlined, 'Edit', onEdit),
          if (onRegenerate != null)
            action(Icons.refresh_rounded, 'Regenerate', onRegenerate),
          action(Icons.copy_rounded, 'Copy', onCopy),
        ],
      ),
    );
  }
}

/// Edits one question before re-sending it. Owns its controller for the same
/// lifecycle reason as [_PromptEditorDialog] below.
class _EditMessageDialog extends StatefulWidget {
  const _EditMessageDialog({required this.initialText});
  final String initialText;

  @override
  State<_EditMessageDialog> createState() => _EditMessageDialogState();
}

class _EditMessageDialogState extends State<_EditMessageDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Edit question'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sending this again replaces the original question and everything '
          'after it.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          autofocus: true,
          minLines: 2,
          maxLines: 6,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text),
        child: const Text('Send'),
      ),
    ],
  );
}

/// Owns its own [TextEditingController].
///
/// The caller used to create the controller, `await showDialog(...)`, then
/// dispose it on the next line. That disposes it while the dialog is still
/// animating out with the [TextField] mounted and listening, which tears the
/// element tree down out of order — `InheritedElement.debugDeactivated`
/// then trips its `_dependents.isEmpty` assertion and the screen goes red.
/// Tying the controller to this widget's own lifecycle means it outlives the
/// exit transition and is disposed exactly once, after the field is gone.
class _PromptEditorDialog extends StatefulWidget {
  const _PromptEditorDialog({required this.initialText});
  final String initialText;

  @override
  State<_PromptEditorDialog> createState() => _PromptEditorDialogState();
}

class _PromptEditorDialogState extends State<_PromptEditorDialog> {
  late final TextEditingController controller = TextEditingController(
    text: widget.initialText,
  );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

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
          // Resolved before the await: reaching for the Navigator through
          // `context` afterwards is the same use-after-teardown hazard the
          // controller had.
          final navigator = Navigator.of(context);
          final text = controller.text.trim();
          if (text.isEmpty || text == AiInsightsService.defaultReviewInstruction) {
            await locator<CoachPromptStore>().clear();
          } else {
            await locator<CoachPromptStore>().save(text);
          }
          navigator.pop(true);
        },
        child: const Text('Save'),
      ),
    ],
  );
}
