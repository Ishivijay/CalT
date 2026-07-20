import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/features/photo_log/domain/ai_photo_meal_item.dart';

void main() {
  test('editing an AI estimate preserves unedited nutrition fields', () {
    const original = AiPhotoMealItem(
      name: 'Pasta', grams: 250, kcal: 450, proteinG: 15, carbsG: 70,
      fatG: 12, confidence: AiEstimateConfidence.medium,
    );
    final edited = original.copyWith(name: 'Wholewheat pasta', grams: 280, clearReferenceMeal: true);
    expect(edited.name, 'Wholewheat pasta');
    expect(edited.grams, 280);
    expect(edited.kcal, 450);
    expect(edited.verified, isFalse);
  });
}
