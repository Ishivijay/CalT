import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';

class NutritionPeriodSummary {
  const NutritionPeriodSummary({
    required this.days,
    required this.loggedDays,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.mealCounts,
    required this.foodNames,
  });
  final int days;
  final int loggedDays;
  final double kcal;
  final double protein;
  final double carbs;
  final double fat;
  final Map<IntakeTypeEntity, int> mealCounts;
  final List<String> foodNames;
  double get kcalDailyAverage => kcal / days;
  double get proteinDailyAverage => protein / days;
}

class InsightsAggregation {
  const InsightsAggregation({
    required this.last7Days,
    required this.last30Days,
  });
  final NutritionPeriodSummary last7Days;
  final NutritionPeriodSummary last30Days;
}

/// Pure aggregation kept independent from Hive/UI so it can be tested without
/// device services and so the prompt never sends raw diary records.
class InsightsAggregator {
  const InsightsAggregator();
  InsightsAggregation aggregate(List<IntakeEntity> entries, DateTime now) =>
      InsightsAggregation(
        last7Days: _period(entries, now, 7),
        last30Days: _period(entries, now, 30),
      );

  NutritionPeriodSummary _period(
    List<IntakeEntity> entries,
    DateTime now,
    int days,
  ) {
    final today = DateTime(now.year, now.month, now.day);
    final from = today.subtract(Duration(days: days - 1));
    final filtered = entries
        .where(
          (entry) =>
              !entry.dateTime.isBefore(from) &&
              entry.dateTime.isBefore(today.add(const Duration(days: 1))),
        )
        .toList();
    final logged = filtered
        .map(
          (entry) => DateTime(
            entry.dateTime.year,
            entry.dateTime.month,
            entry.dateTime.day,
          ),
        )
        .toSet()
        .length;
    final counts = {for (final type in IntakeTypeEntity.values) type: 0};
    double kcal = 0, protein = 0, carbs = 0, fat = 0;
    final names = <String>{};
    for (final entry in filtered) {
      kcal += entry.totalKcal;
      protein += entry.totalProteinsGram;
      carbs += entry.totalCarbsGram;
      fat += entry.totalFatsGram;
      counts[entry.type] = counts[entry.type]! + 1;
      final name = entry.meal.name?.trim();
      if (name != null && name.isNotEmpty && names.length < 24) names.add(name);
    }
    return NutritionPeriodSummary(
      days: days,
      loggedDays: logged,
      kcal: kcal,
      protein: protein,
      carbs: carbs,
      fat: fat,
      mealCounts: counts,
      foodNames: names.toList(),
    );
  }
}
