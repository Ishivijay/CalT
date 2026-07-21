import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CalTCoachChatMessage {
  const CalTCoachChatMessage({required this.text, required this.isUser});

  final String text;
  final bool isUser;

  Map<String, dynamic> toJson() => {'text': text, 'isUser': isUser};

  factory CalTCoachChatMessage.fromJson(Map<String, dynamic> json) =>
      CalTCoachChatMessage(
        text: json['text']?.toString() ?? '',
        isUser: json['isUser'] == true,
      );
}

/// Keeps the private CalT conversation on this device, alongside the other
/// AI-related local data. Only the most recent exchanges are retained.
class CalTCoachChatHistoryStore {
  CalTCoachChatHistoryStore(this._storage);

  static const _key = 'calt_coach_chat_history_v1';
  static const _maxMessages = 30;
  final FlutterSecureStorage _storage;

  Future<List<CalTCoachChatMessage>> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map>()
          .map(
            (item) =>
                CalTCoachChatMessage.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((message) => message.text.isNotEmpty)
          .toList();
    } on FormatException {
      return [];
    }
  }

  Future<void> save(List<CalTCoachChatMessage> messages) {
    final recent = messages.length > _maxMessages
        ? messages.sublist(messages.length - _maxMessages)
        : messages;
    return _storage.write(
      key: _key,
      value: jsonEncode(recent.map((message) => message.toJson()).toList()),
    );
  }
}
