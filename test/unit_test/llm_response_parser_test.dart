import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/features/ai_provider/data/llm_response_parser.dart';

void main() {
  group('parseJsonObject', () {
    test('parses a plain JSON object', () {
      expect(parseJsonObject('{"items":[]}'), {'items': []});
    });
    test('parses JSON wrapped in a Markdown fence', () {
      expect(parseJsonObject('```json\n{"kcal": 300}\n```'), {'kcal': 300});
    });
    test('returns null for malformed model output', () {
      expect(parseJsonObject('I cannot estimate {kcal: ???}'), isNull);
    });
  });
}
