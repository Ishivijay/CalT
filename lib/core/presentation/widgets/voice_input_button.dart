import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as speech;

/// A trailing control for free-text fields. Dictation replaces the field with
/// the latest recognised phrase, just like typing a new search or title.
class VoiceInputButton extends StatefulWidget {
  const VoiceInputButton({super.key, required this.controller, this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  @override
  State<VoiceInputButton> createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends State<VoiceInputButton> {
  final speech.SpeechToText _speech = speech.SpeechToText();
  bool _listening = false;

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }

    final available = await _speech.initialize(
      onStatus: (status) {
        if (mounted && (status == 'done' || status == 'notListening')) {
          setState(() => _listening = false);
        }
      },
      onError: (_) {
        if (mounted) setState(() => _listening = false);
      },
    );
    if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Voice input is unavailable. Check microphone permission.',
            ),
          ),
        );
      }
      return;
    }

    setState(() => _listening = true);
    await _speech.listen(
      onResult: (result) {
        final text = result.recognizedWords.trim();
        if (text.isEmpty) return;
        widget.controller.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
        widget.onChanged?.call(text);
      },
    );
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: _listening ? 'Stop voice input' : 'Use voice input',
    onPressed: _toggle,
    icon: Icon(
      _listening ? Icons.mic_rounded : Icons.mic_none_rounded,
      color: _listening ? Theme.of(context).colorScheme.primary : null,
    ),
  );
}
