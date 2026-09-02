import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_activity_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_intake_usecase.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_activity/presentation/add_activity_screen.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_screen.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/meal_item_card.dart';
import 'package:opennutritracker/features/photo_log/presentation/photo_log_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';

class AddItemBottomSheet extends StatelessWidget {
  final DateTime day;
  final bool showActivityTracking;
  final bool usesImperialUnits;

  const AddItemBottomSheet({
    super.key,
    required this.day,
    this.showActivityTracking = true,
    this.usesImperialUnits = false,
  });

  @override
  Widget build(BuildContext context) {
    // Every row here is deliberately compact (dense ListTiles, no subtitles,
    // recent items as a horizontal strip instead of stacked cards) so the
    // whole menu fits on one screen without scrolling on a typical phone.
    // SingleChildScrollView stays as a safety net for unusually short
    // screens rather than risking an overflow.
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                S.of(context).addItemLabel,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            _buildRecentSection(context),
            if (showActivityTracking)
              _row(
                context,
                identifier: 'add-item-activity',
                icon: UserActivityEntity.getIconData(),
                label: S.of(context).activityLabel,
                onTap: () => _showAddActivityScreen(context),
              ),
            _row(
              context,
              identifier: 'add-item-photo-log',
              icon: Icons.auto_awesome_outlined,
              label: 'Log with photo',
              iconColor: Theme.of(context).colorScheme.primary,
              onTap: () => _showPhotoLogScreen(context),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            _row(
              context,
              identifier: 'add-item-breakfast',
              icon: IntakeTypeEntity.breakfast.getIconData(),
              label: S.of(context).breakfastLabel,
              onTap: () => _showAddItemScreen(context, AddMealType.breakfastType),
            ),
            _row(
              context,
              identifier: 'add-item-lunch',
              icon: IntakeTypeEntity.lunch.getIconData(),
              label: S.of(context).lunchLabel,
              onTap: () => _showAddItemScreen(context, AddMealType.lunchType),
            ),
            _row(
              context,
              identifier: 'add-item-dinner',
              icon: IntakeTypeEntity.dinner.getIconData(),
              label: S.of(context).dinnerLabel,
              onTap: () => _showAddItemScreen(context, AddMealType.dinnerType),
            ),
            _row(
              context,
              identifier: 'add-item-snack',
              icon: IntakeTypeEntity.snack.getIconData(),
              label: S.of(context).snackLabel,
              onTap: () => _showAddItemScreen(context, AddMealType.snackType),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            _row(
              context,
              identifier: 'add-item-recipes',
              icon: Icons.menu_book_outlined,
              label: S.of(context).recipesLabel,
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed(NavigationOptions.recipesRoute);
              },
            ),
            const SizedBox(height: Dimens.spacing8),
          ],
        ),
      ),
    );
  }

  /// One compact, single-line menu row — icon, label, dense vertical
  /// footprint. No subtitle: with 6-7 of these plus the recent strip on one
  /// sheet, a caption under every row is what was pushing this into
  /// scrolling territory.
  Widget _row(
    BuildContext context, {
    required String identifier,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return Semantics(
      identifier: identifier,
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(vertical: -3),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        minLeadingWidth: 28,
        leading: Icon(icon, color: iconColor, size: 22),
        title: Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildRecentSection(BuildContext context) {
    // Guard for widget tests / early startup where the use case isn't wired.
    if (!locator.isRegistered<GetIntakeUsecase>()) {
      return const SizedBox.shrink();
    }
    return FutureBuilder<List<IntakeEntity>>(
      future: locator<GetIntakeUsecase>().getRecentIntake(),
      builder: (context, snapshot) {
        final intakes = snapshot.data;
        if (intakes == null || intakes.isEmpty) return const SizedBox.shrink();
        // getRecentIntake() already returns the most-recent *unique* foods
        // (the data source dedupes by meal), so take the first few for quick
        // re-logging. A horizontal strip instead of a stacked list — 4
        // full-width MealItemCards ate more vertical space than the rest of
        // the menu combined.
        final recent = intakes.take(6).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                S.of(context).recentlyAddedLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            SizedBox(
              height: 108,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: recent.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, index) {
                  final intake = recent[index];
                  return SizedBox(
                    width: 220,
                    child: MealItemCard(
                      day: day,
                      mealEntity: intake.meal,
                      addMealType: AddMealExtension.fromIntakeTypeEntity(intake.type),
                      usesImperialUnits: usesImperialUnits,
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
          ],
        );
      },
    );
  }

  void _showAddItemScreen(BuildContext context, AddMealType itemType) {
    Navigator.of(context).pop(); // Close bottom sheet
    Navigator.of(context).pushNamed(
      NavigationOptions.addMealRoute,
      arguments: AddMealScreenArguments(itemType, day),
    );
  }

  void _showAddActivityScreen(BuildContext context) {
    Navigator.of(context).pop();
    Navigator.of(context).pushNamed(
      NavigationOptions.addActivityRoute,
      arguments: AddActivityScreenArguments(day: day),
    );
  }

  void _showPhotoLogScreen(BuildContext context) {
    Navigator.of(context).pop();
    Navigator.of(context).pushNamed(
      NavigationOptions.photoLogRoute,
      arguments: PhotoLogScreenArguments(day: day),
    );
  }
}
