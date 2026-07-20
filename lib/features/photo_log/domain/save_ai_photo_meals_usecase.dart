import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_kcal_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_macro_goal_usecase.dart';
import 'package:opennutritracker/core/utils/id_generator.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/photo_log/domain/ai_photo_meal_item.dart';

/// Saves confirmed estimates through the same intake and tracked-day services
/// used by manual and quick-add meals; nothing is persisted before review.
class SaveAiPhotoMealsUsecase {
  SaveAiPhotoMealsUsecase(this._addIntake, this._trackedDays, this._kcalGoal, this._macroGoal);
  final AddIntakeUsecase _addIntake;
  final AddTrackedDayUsecase _trackedDays;
  final GetKcalGoalUsecase _kcalGoal;
  final GetMacroGoalUsecase _macroGoal;

  Future<void> save(List<AiPhotoMealItem> items, IntakeTypeEntity type, DateTime day) async {
    if (items.isEmpty) return;
    if (!await _trackedDays.hasTrackedDay(day)) {
      final kcal = await _kcalGoal.getKcalGoal();
      await _trackedDays.addNewTrackedDay(day, kcal, await _macroGoal.getCarbsGoal(kcal), await _macroGoal.getFatsGoal(kcal), await _macroGoal.getProteinsGoal(kcal));
    }
    for (final item in items) {
      final intake = _intakeFor(item, type, day);
      await _addIntake.addIntake(intake);
      await _trackedDays.addDayCaloriesTracked(day, intake.totalKcal);
      await _trackedDays.addDayMacrosTracked(day, carbsTracked: intake.totalCarbsGram, fatTracked: intake.totalFatsGram, proteinTracked: intake.totalProteinsGram);
    }
  }

  IntakeEntity _intakeFor(AiPhotoMealItem item, IntakeTypeEntity type, DateTime day) {
    final double grams = item.grams <= 0 ? 100.0 : item.grams;
    final meal = item.referenceMeal ?? MealEntity(
      code: IdGenerator.getUniqueID(), name: item.name, url: null, mealQuantity: '100', mealUnit: 'g', servingQuantity: null, servingUnit: 'g', servingSize: '',
      nutriments: MealNutrimentsEntity(energyKcal100: item.kcal * 100 / grams, carbohydrates100: item.carbsG * 100 / grams, fat100: item.fatG * 100 / grams, proteins100: item.proteinG * 100 / grams, sugars100: null, saturatedFat100: null, fiber100: null),
      source: MealSourceEntity.custom,
    );
    return IntakeEntity(id: IdGenerator.getUniqueID(), unit: 'g', amount: grams, type: type, meal: meal, dateTime: day);
  }
}
