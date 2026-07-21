import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/delete_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_kcal_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_macro_goal_usecase.dart';
import 'package:opennutritracker/core/utils/id_generator.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/ai_insights/data/ai_insights_cache_store.dart';

/// Adds an optional, clearly labelled seven-day diary for trying CalT coach.
/// It is never inserted automatically. Reloading the test diary replaces only
/// prior CalT test entries, leaving the person's own foods untouched.
class CoachDemoDiarySeeder {
  CoachDemoDiarySeeder(
    this._addIntake,
    this._trackedDay,
    this._kcalGoal,
    this._macroGoal,
    this._insightsCache,
    this._getIntake,
    this._deleteIntake,
  );

  final AddIntakeUsecase _addIntake;
  final AddTrackedDayUsecase _trackedDay;
  final GetKcalGoalUsecase _kcalGoal;
  final GetMacroGoalUsecase _macroGoal;
  final AiInsightsCacheStore _insightsCache;
  final GetIntakeUsecase _getIntake;
  final DeleteIntakeUsecase _deleteIntake;

  static const _testPrefix = 'CalT test · ';
  static const _legacySampleNames = {
    'Greek yogurt, berries & oats',
    'Lentil quinoa bowl',
    'Apple with peanut butter',
    'Chicken pasta with vegetables',
    'Eggs, toast & avocado',
    'Turkey salad wrap',
    'Protein shake and banana',
    'Salmon, rice & roasted vegetables',
  };

  Future<void> seed() async {
    await removeSampleMeals();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (var dayOffset = 6; dayOffset >= 0; dayOffset--) {
      await _seedDay(
        today.subtract(Duration(days: dayOffset)),
        _weekMenus[6 - dayOffset],
      );
    }
    await _insightsCache.clear();
  }

  /// Removes both the old two-day sample data and the current named test data.
  /// This is deliberately exact so ordinary user-created entries are retained.
  Future<int> removeSampleMeals() async {
    final samples = (await _getIntake.getCustomMealIntakes())
        .where(
          (intake) =>
              (intake.meal.name ?? '').startsWith(_testPrefix) ||
              _legacySampleNames.contains(intake.meal.name),
        )
        .toList();
    for (final intake in samples) {
      await _deleteIntake.deleteIntake(intake);
      await _trackedDay.removeDayCaloriesTracked(
        intake.dateTime,
        intake.totalKcal,
      );
      await _trackedDay.removeDayMacrosTracked(
        intake.dateTime,
        carbsTracked: intake.totalCarbsGram,
        fatTracked: intake.totalFatsGram,
        proteinTracked: intake.totalProteinsGram,
      );
    }
    if (samples.isNotEmpty) await _insightsCache.clear();
    return samples.length;
  }

  static final _weekMenus = <List<_DemoFood>>[
    [
      _DemoFood(
        'Overnight oats and berries',
        410,
        58,
        10,
        22,
        IntakeTypeEntity.breakfast,
      ),
      _DemoFood(
        'Chicken quinoa salad',
        560,
        55,
        18,
        43,
        IntakeTypeEntity.lunch,
      ),
      _DemoFood('Apple and almonds', 240, 30, 12, 6, IntakeTypeEntity.snack),
      _DemoFood(
        'Tofu vegetable stir-fry',
        610,
        70,
        20,
        31,
        IntakeTypeEntity.dinner,
      ),
    ],
    [
      _DemoFood(
        'Eggs, toast and avocado',
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
      _DemoFood('Salmon rice bowl', 640, 62, 22, 42, IntakeTypeEntity.dinner),
    ],
    [
      _DemoFood(
        'Yogurt, granola and kiwi',
        380,
        52,
        8,
        25,
        IntakeTypeEntity.breakfast,
      ),
      _DemoFood(
        'Lentil soup and sourdough',
        510,
        76,
        11,
        25,
        IntakeTypeEntity.lunch,
      ),
      _DemoFood(
        'Cottage cheese and peach',
        220,
        22,
        5,
        24,
        IntakeTypeEntity.snack,
      ),
      _DemoFood(
        'Beef, potatoes and greens',
        690,
        64,
        25,
        48,
        IntakeTypeEntity.dinner,
      ),
    ],
    [
      _DemoFood(
        'Peanut butter banana toast',
        430,
        54,
        18,
        16,
        IntakeTypeEntity.breakfast,
      ),
      _DemoFood('Tuna pasta salad', 590, 68, 17, 39, IntakeTypeEntity.lunch),
      _DemoFood(
        'Dark chocolate and berries',
        210,
        29,
        10,
        3,
        IntakeTypeEntity.snack,
      ),
      _DemoFood(
        'Chicken curry and rice',
        700,
        77,
        21,
        46,
        IntakeTypeEntity.dinner,
      ),
    ],
    [
      _DemoFood(
        'Veggie omelette and toast',
        400,
        34,
        21,
        27,
        IntakeTypeEntity.breakfast,
      ),
      _DemoFood('Chickpea grain bowl', 550, 79, 14, 23, IntakeTypeEntity.lunch),
      _DemoFood('Skyr and walnuts', 230, 15, 12, 20, IntakeTypeEntity.snack),
      _DemoFood(
        'Prawn noodles with vegetables',
        620,
        74,
        14,
        38,
        IntakeTypeEntity.dinner,
      ),
    ],
    [
      _DemoFood(
        'Porridge with protein milk',
        390,
        55,
        9,
        26,
        IntakeTypeEntity.breakfast,
      ),
      _DemoFood(
        'Chicken burrito bowl',
        650,
        72,
        20,
        45,
        IntakeTypeEntity.lunch,
      ),
      _DemoFood('Hummus and carrots', 200, 22, 10, 7, IntakeTypeEntity.snack),
      _DemoFood(
        'Turkey chilli and rice',
        670,
        75,
        17,
        47,
        IntakeTypeEntity.dinner,
      ),
    ],
    [
      _DemoFood(
        'Eggs, toast and avocado',
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
        'Salmon, rice and roasted vegetables',
        640,
        62,
        22,
        42,
        IntakeTypeEntity.dinner,
      ),
    ],
  ];

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
          name: '$_testPrefix${food.name}',
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
