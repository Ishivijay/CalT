import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_kcal_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_macro_goal_usecase.dart';
import 'package:opennutritracker/core/utils/id_generator.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/ai_insights/data/ai_insights_cache_store.dart';

/// Adds a deliberately varied, two-day diary for trying the CalT coach.
/// It is offered only on an empty home day, so it never silently changes a
/// real diary. Every entry is named and stored as a regular editable meal.
class CoachDemoDiarySeeder {
  CoachDemoDiarySeeder(
    this._addIntake,
    this._trackedDay,
    this._kcalGoal,
    this._macroGoal,
    this._insightsCache,
  );

  final AddIntakeUsecase _addIntake;
  final AddTrackedDayUsecase _trackedDay;
  final GetKcalGoalUsecase _kcalGoal;
  final GetMacroGoalUsecase _macroGoal;
  final AiInsightsCacheStore _insightsCache;

  Future<void> seed() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    await _seedDay(yesterday, [
      _DemoFood(
        'Greek yogurt, berries & oats',
        390,
        52,
        8,
        25,
        IntakeTypeEntity.breakfast,
      ),
      _DemoFood('Lentil quinoa bowl', 560, 78, 16, 24, IntakeTypeEntity.lunch),
      _DemoFood(
        'Apple with peanut butter',
        260,
        31,
        13,
        7,
        IntakeTypeEntity.snack,
      ),
      _DemoFood(
        'Chicken pasta with vegetables',
        680,
        75,
        18,
        44,
        IntakeTypeEntity.dinner,
      ),
    ]);
    await _seedDay(today, [
      _DemoFood(
        'Eggs, toast & avocado',
        460,
        36,
        25,
        24,
        IntakeTypeEntity.breakfast,
      ),
      _DemoFood('Turkey salad wrap', 520, 54, 17, 38, IntakeTypeEntity.lunch),
      _DemoFood(
        'Protein shake and banana',
        310,
        35,
        4,
        29,
        IntakeTypeEntity.snack,
      ),
      _DemoFood(
        'Salmon, rice & roasted vegetables',
        640,
        62,
        22,
        42,
        IntakeTypeEntity.dinner,
      ),
    ]);
    await _insightsCache.clear();
  }

  Future<void> _seedDay(DateTime day, List<_DemoFood> foods) async {
    if (!await _trackedDay.hasTrackedDay(day)) {
      final kcalGoal = await _kcalGoal.getKcalGoal();
      await _trackedDay.addNewTrackedDay(
        day,
        kcalGoal,
        await _macroGoal.getCarbsGoal(kcalGoal),
        await _macroGoal.getFatsGoal(kcalGoal),
        await _macroGoal.getProteinsGoal(kcalGoal),
      );
    }
    for (final food in foods) {
      final intake = IntakeEntity(
        id: IdGenerator.getUniqueID(),
        unit: 'g',
        amount: 100,
        type: food.type,
        dateTime: day.add(Duration(hours: _hourFor(food.type))),
        meal: MealEntity(
          code: IdGenerator.getUniqueID(),
          name: food.name,
          url: null,
          mealQuantity: '100',
          mealUnit: 'g',
          servingQuantity: 100,
          servingUnit: 'g',
          servingSize: '1 serving',
          source: MealSourceEntity.custom,
          nutriments: MealNutrimentsEntity(
            energyKcal100: food.kcal,
            carbohydrates100: food.carbs,
            fat100: food.fat,
            proteins100: food.protein,
            sugars100: null,
            saturatedFat100: null,
            fiber100: null,
          ),
        ),
      );
      await _addIntake.addIntake(intake);
      await _trackedDay.addDayCaloriesTracked(day, intake.totalKcal);
      await _trackedDay.addDayMacrosTracked(
        day,
        carbsTracked: intake.totalCarbsGram,
        fatTracked: intake.totalFatsGram,
        proteinTracked: intake.totalProteinsGram,
      );
    }
  }

  int _hourFor(IntakeTypeEntity type) => switch (type) {
    IntakeTypeEntity.breakfast => 8,
    IntakeTypeEntity.lunch => 13,
    IntakeTypeEntity.snack => 16,
    IntakeTypeEntity.dinner => 19,
  };
}

class _DemoFood {
  const _DemoFood(
    this.name,
    this.kcal,
    this.carbs,
    this.fat,
    this.protein,
    this.type,
  );

  final String name;
  final double kcal;
  final double carbs;
  final double fat;
  final double protein;
  final IntakeTypeEntity type;
}
