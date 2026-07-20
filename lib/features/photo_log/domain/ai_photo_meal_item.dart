import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';

enum AiEstimateConfidence { low, medium, high }

class AiPhotoMealItem {
  const AiPhotoMealItem({
    required this.name,
    required this.grams,
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.confidence,
    this.referenceMeal,
  });
  final String name;
  final double grams;
  final double kcal;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final AiEstimateConfidence confidence;
  final MealEntity? referenceMeal;
  bool get verified => referenceMeal != null;

  AiPhotoMealItem copyWith({
    String? name, double? grams, double? kcal, double? proteinG, double? carbsG,
    double? fatG, MealEntity? referenceMeal, bool clearReferenceMeal = false,
  }) => AiPhotoMealItem(
    name: name ?? this.name, grams: grams ?? this.grams, kcal: kcal ?? this.kcal,
    proteinG: proteinG ?? this.proteinG, carbsG: carbsG ?? this.carbsG,
    fatG: fatG ?? this.fatG, confidence: confidence,
    referenceMeal: clearReferenceMeal ? null : referenceMeal ?? this.referenceMeal,
  );
}

class AiPhotoMealAnalysis {
  const AiPhotoMealAnalysis({required this.items, required this.notes});
  final List<AiPhotoMealItem> items;
  final String notes;
}
