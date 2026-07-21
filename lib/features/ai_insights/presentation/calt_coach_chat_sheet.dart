import 'package:flutter/material.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/ai_insights/data/calt_coach_chat_history_store.dart';
import 'package:opennutritracker/features/ai_insights/data/ai_insights_service.dart';
import 'package:opennutritracker/features/ai_provider/domain/llm_provider.dart';

Future<void> showCalTCoachChat(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _CalTCoachChatSheet(),
    );

class _CalTCoachChatSheet extends StatefulWidget {
  const _CalTCoachChatSheet();

  @override
  State<_CalTCoachChatSheet> createState() => _CalTCoachChatSheetState();
}

class _CalTCoachChatSheetState extends State<_CalTCoachChatSheet> {
  final _question = TextEditingController();
  final _messages = <CalTCoachChatMessage>[];
  bool _asking = false;
  bool _loadingHistory = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
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
      _messages.add(CalTCoachChatMessage(text: question, isUser: true));
      _question.clear();
    });
    await _saveHistory();
    try {
      final answer = await locator<AiInsightsService>().answerQuestion(
        question,
      );
      if (mounted) {
        setState(
          () =>
              _messages.add(CalTCoachChatMessage(text: answer, isUser: false)),
        );
        await _saveHistory();
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
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final availableHeight = MediaQuery.sizeOf(context).height - keyboardInset;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: SizedBox(
          height: availableHeight * .78,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.auto_awesome_rounded),
                title: const Text('Chat with CalT coach'),
                subtitle: const Text('Ask about today\'s meals and your goals'),
                trailing: IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _loadingHistory
                    ? const Center(child: CircularProgressIndicator())
                    : _messages.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Try: “How can I add more protein to today\'s meals?”',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, index) {
                          final message = _messages[index];
                          return Align(
                            alignment: message.isUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 330),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: message.isUser
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.primaryContainer
                                      : Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(message.text),
                                ),
                              ),
                            ),
                          );
                        },
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
                  onSubmitted: (_) => _ask(),
                  decoration: InputDecoration(
                    hintText: 'Ask CalT coach…',
                    border: const OutlineInputBorder(),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Send question',
                          onPressed: _asking ? null : _ask,
                          icon: _asking
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
