import 'package:opennutritracker/features/add_meal/domain/usecase/search_products_usecase.dart';
import 'package:opennutritracker/features/photo_log/domain/ai_photo_meal_item.dart';

/// Attempts a conservative canonical-food match. A failed lookup is normal and
/// intentionally leaves the AI estimate editable instead of substituting an
/// unrelated branded product.
class PhotoFoodMatcher {
  PhotoFoodMatcher(this._search);
  final SearchProductsUseCase _search;

  Future<AiPhotoMealItem> verify(AiPhotoMealItem item) async {
    final normalized = _normalize(item.name);
    if (normalized.isEmpty) return item;
    final result = await _search.searchFDCFoodByString(item.name);
    for (final meal in result.meals) {
      final candidate = _normalize(meal.name ?? '');
      if (candidate.isNotEmpty && (candidate.contains(normalized) || normalized.contains(candidate))) {
        return item.copyWith(referenceMeal: meal);
      }
    }
    return item;
  }

  String _normalize(String value) => value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), '').trim();
}
