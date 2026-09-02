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
/// AI-related local data. Scoped to the current calendar day: the coach's
/// answers only ever reason about *today's* diary (see
/// AiInsightsService._todayEntries/_todayActivities), so surfacing a
/// previous day's questions and answers next to today's would misrepresent
/// stale advice as still current, not just clutter the sheet. A single key
/// with an embedded `savedAt` timestamp (mirroring AiInsightsCacheStore's
/// day-check) keeps this self-resetting without growing a new storage
/// entry per day forever — a stale day's content just reads back empty and
/// gets overwritten by the next save().
class CalTCoachChatHistoryStore {
  CalTCoachChatHistoryStore(this._storage);

  static const _key = 'calt_coach_chat_history_v2';
  static const _maxMessages = 30;
  final FlutterSecureStorage _storage;

  Future<List<CalTCoachChatMessage>> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final savedAt = DateTime.tryParse(decoded['savedAt']?.toString() ?? '');
      if (savedAt == null || !_isToday(savedAt)) return [];
      final rawMessages = decoded['messages'] as List<dynamic>? ?? [];
      return rawMessages
          .whereType<Map>()
          .map(
            (item) =>
                CalTCoachChatMessage.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((message) => message.text.isNotEmpty)
          .toList();
    } on FormatException {
      return [];
    } on TypeError {
      return [];
    }
  }

  Future<void> save(List<CalTCoachChatMessage> messages) {
    final recent = messages.length > _maxMessages
        ? messages.sublist(messages.length - _maxMessages)
        : messages;
    return _storage.write(
      key: _key,
      value: jsonEncode({
        'savedAt': DateTime.now().toIso8601String(),
        'messages': recent.map((message) => message.toJson()).toList(),
      }),
    );
  }

  bool _isToday(DateTime dateTime) {
    final now = DateTime.now();
    return dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day;
  }
}
