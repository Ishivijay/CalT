import 'package:logging/logging.dart';
import 'package:opennutritracker/core/data/data_source/custom_meal_data_source.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_kcal_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_macro_goal_usecase.dart';
import 'package:opennutritracker/core/utils/id_generator.dart';
import 'package:opennutritracker/core/utils/user_image_storage.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/photo_log/domain/ai_photo_meal_item.dart';

/// Saves confirmed estimates through the same intake and tracked-day services
/// used by manual and quick-add meals; nothing is persisted before review.
class SaveAiPhotoMealsUsecase {
  SaveAiPhotoMealsUsecase(
    this._addIntake,
    this._trackedDays,
    this._kcalGoal,
    this._macroGoal,
    this._customMeals,
  );
  final AddIntakeUsecase _addIntake;
  final AddTrackedDayUsecase _trackedDays;
  final GetKcalGoalUsecase _kcalGoal;
  final GetMacroGoalUsecase _macroGoal;
  final CustomMealDataSource _customMeals;
  final _log = Logger('SaveAiPhotoMealsUsecase');

  /// [photoSourcePath] is the on-disk path of the picture the estimate was
  /// generated from (the `image_picker` result, before its in-memory
  /// compressed copy sent to the LLM). When present, every freshly-created
  /// custom meal from this save (i.e. items with no [AiPhotoMealItem.referenceMeal])
  /// gets that photo attached so it shows up as a thumbnail in the diary.
  /// Matched items (already-existing foods from the database) keep their
  /// own thumbnail untouched — the snack photo shouldn't get stamped onto
  /// a shared food-DB entry other intakes also reference.
  Future<void> save(
    List<AiPhotoMealItem> items,
    IntakeTypeEntity type,
    DateTime day, {
    String? photoSourcePath,
  }) async {
    if (items.isEmpty) return;
    if (!await _trackedDays.hasTrackedDay(day)) {
      final kcal = await _kcalGoal.getKcalGoal();
      await _trackedDays.addNewTrackedDay(
        day,
        kcal,
        await _macroGoal.getCarbsGoal(kcal),
        await _macroGoal.getFatsGoal(kcal),
        await _macroGoal.getProteinsGoal(kcal),
      );
    }
    final relativeImagePath = await _importPhoto(photoSourcePath);
    for (final item in items) {
      final intake = _intakeFor(item, type, day, relativeImagePath);
      await _addIntake.addIntake(intake);
      await _trackedDays.addDayCaloriesTracked(day, intake.totalKcal);
      await _trackedDays.addDayMacrosTracked(
        day,
        carbsTracked: intake.totalCarbsGram,
        fatTracked: intake.totalFatsGram,
        proteinTracked: intake.totalProteinsGram,
      );
      // Mirror the meal into the custom-meals box (same as a manually typed
      // custom meal) so its photo travels with data export/import — export
      // only walks CustomMealBox + RecipeBox for image bytes, not IntakeBox.
      if (relativeImagePath != null && item.referenceMeal == null) {
        await _customMeals.saveCustomMeal(MealDBO.fromMealEntity(intake.meal));
      }
    }
  }

  /// Best-effort: a photo that fails to persist (e.g. the picker's temp
  /// file was already reclaimed by the OS) must not block saving the meal
  /// itself — the estimate is the part the user reviewed and confirmed.
  Future<String?> _importPhoto(String? sourcePath) async {
    if (sourcePath == null) return null;
    try {
      return await UserImageStorage.importFrom(
        kind: UserImageKind.meal,
        ownerId: IdGenerator.getUniqueID(),
        sourcePath: sourcePath,
      );
    } catch (e, st) {
      _log.warning('Failed to persist photo-log image', e, st);
      return null;
    }
  }

  IntakeEntity _intakeFor(
    AiPhotoMealItem item,
    IntakeTypeEntity type,
    DateTime day,
    String? relativeImagePath,
  ) {
    final double grams = item.grams <= 0 ? 100.0 : item.grams;
    final meal =
        item.referenceMeal ??
        MealEntity(
          code: IdGenerator.getUniqueID(),
          name: item.name,
          url: null,
          mealQuantity: '100',
          mealUnit: 'g',
          servingQuantity: null,
          servingUnit: 'g',
          servingSize: '',
          nutriments: MealNutrimentsEntity(
            energyKcal100: item.kcal * 100 / grams,
            carbohydrates100: item.carbsG * 100 / grams,
            fat100: item.fatG * 100 / grams,
            proteins100: item.proteinG * 100 / grams,
            sugars100: null,
            saturatedFat100: null,
            fiber100: null,
          ),
          source: MealSourceEntity.custom,
          localImagePath: relativeImagePath,
        );
    return IntakeEntity(
      id: IdGenerator.getUniqueID(),
      unit: 'g',
      amount: grams,
      type: type,
      meal: meal,
      dateTime: day,
    );
  }
}
