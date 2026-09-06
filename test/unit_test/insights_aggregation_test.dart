import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/ai_insights/domain/insights_aggregation.dart';

void main() {
  IntakeEntity entry(DateTime date, IntakeTypeEntity type, double amount) => IntakeEntity(
    id: '$date-$type', unit: 'g', amount: amount, type: type, dateTime: date,
    meal: MealEntity(code: 'meal-$type', name: 'Meal', url: null, mealQuantity: '100', mealUnit: 'g', servingQuantity: null, servingUnit: 'g', servingSize: '', source: MealSourceEntity.custom, nutriments: const MealNutrimentsEntity(energyKcal100: 200, carbohydrates100: 20, fat100: 10, proteins100: 5, sugars100: null, saturatedFat100: null, fiber100: null)),
  );

  test('separates the 7 and 30 day windows and sums nutrition totals', () {
    final now = DateTime(2026, 7, 20, 12);
    final result = const InsightsAggregator().aggregate([
      entry(DateTime(2026, 7, 20, 8), IntakeTypeEntity.breakfast, 100),
      entry(DateTime(2026, 7, 14, 12), IntakeTypeEntity.lunch, 50),
      entry(DateTime(2026, 6, 20, 12), IntakeTypeEntity.dinner, 100),
    ], now);
    // The 7-day window runs from `today - 6 days`, so it covers the 14th
    // through the 20th inclusive — seven calendar days ending today. The
    // lunch on the 14th sits exactly on that boundary and counts; the
    // dinner on 6-20 falls a day outside the 30-day window and does not.
    expect(result.last7Days.kcal, 300);
    expect(result.last7Days.loggedDays, 2);
    expect(result.last30Days.kcal, 300);
    expect(result.last30Days.mealCounts[IntakeTypeEntity.lunch], 1);
    expect(result.last30Days.mealCounts[IntakeTypeEntity.dinner], 0);
  });
}
