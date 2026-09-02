import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/core/presentation/sources_screen.dart';
import 'package:opennutritracker/core/presentation/widgets/app_card.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/core/utils/calc/unit_calc.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/main_tab_controller.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:provider/provider.dart';

class DashboardWidget extends StatefulWidget {
  final double totalKcalDaily;
  final double totalKcalLeft;
  final double totalKcalSupplied;
  final double totalKcalBurned;
  final double totalCarbsIntake;
  final double totalFatsIntake;
  final double totalProteinsIntake;
  final double totalCarbsGoal;
  final double totalFatsGoal;
  final double totalProteinsGoal;

  const DashboardWidget({
    super.key,
    required this.totalKcalSupplied,
    required this.totalKcalBurned,
    required this.totalKcalDaily,
    required this.totalKcalLeft,
    required this.totalCarbsIntake,
    required this.totalFatsIntake,
    required this.totalProteinsIntake,
    required this.totalCarbsGoal,
    required this.totalFatsGoal,
    required this.totalProteinsGoal,
  });

  @override
  State<DashboardWidget> createState() => _DashboardWidgetState();
}

class _DashboardWidgetState extends State<DashboardWidget> {
  @override
  Widget build(BuildContext context) {
    double kcalValue = 0;
    double gaugeValue = 0;
    final usesKilojoules = context.watch<EnergyUnitProvider>().usesKilojoules;
    String kcalLabelText = usesKilojoules
        ? '${S.of(context).kjLabel} ${S.of(context).energyLeftLabel}'
        : S.of(context).kcalLeftLabel;

    if (widget.totalKcalLeft > widget.totalKcalDaily) {
      kcalValue = widget.totalKcalDaily;
      gaugeValue = 0;
    } else if (widget.totalKcalLeft < 0) {
      kcalValue = widget.totalKcalLeft.abs();
      gaugeValue = 1;
      kcalLabelText = usesKilojoules
          ? '${S.of(context).kjLabel} ${S.of(context).energyTooMuchLabel}'
          : S.of(context).kcalTooMuchLabel;
    } else {
      kcalValue = widget.totalKcalLeft;
      gaugeValue =
          (widget.totalKcalDaily - widget.totalKcalLeft) /
          widget.totalKcalDaily;
    }
    final displayValue = usesKilojoules
        ? UnitCalc.kcalToKj(kcalValue)
        : kcalValue;
    final displaySupplied = usesKilojoules
        ? UnitCalc.kcalToKj(widget.totalKcalSupplied)
        : widget.totalKcalSupplied;
    final displayBurned = usesKilojoules
        ? UnitCalc.kcalToKj(widget.totalKcalBurned)
        : widget.totalKcalBurned;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? AppPalette.dark : AppPalette.light;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimens.spacing16,
        Dimens.spacing8,
        Dimens.spacing16,
        Dimens.spacing4,
      ),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(
          Dimens.spacing20,
          Dimens.spacing20,
          Dimens.spacing20,
          Dimens.spacing20,
        ),
        child: Column(
          children: [
            Row(
              children: [
                _MiniStat(
                  icon: Icons.arrow_downward_rounded,
                  value: '${displaySupplied.toInt()}',
                  label: S.of(context).suppliedLabel,
                  color: palette.proteinColor,
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SourcesScreen()),
                  ),
                  child: Icon(
                    Icons.info_outline_rounded,
                    color: palette.textMuted,
                    size: 22,
                  ),
                ),
                const Spacer(),
                _MiniStat(
                  icon: Icons.local_fire_department_rounded,
                  value: '${displayBurned.toInt()}',
                  label: S.of(context).burnedLabel,
                  color: palette.carbsColor,
                  trailing: true,
                ),
              ],
            ),
            const SizedBox(height: Dimens.spacing16),
            // Tap the ring to jump straight to the Diary — the ring only
            // ever shows today's kcal-left at a glance; anyone who wants the
            // detail behind that number taps through to it instead of the
            // ring itself trying to carry multiple meanings.
            GestureDetector(
              onTap: () => locator<MainTabController>().showDiary(),
              child: Semantics(
                identifier: 'dashboard-ring-open-diary',
                label:
                    '${displayValue.toInt()} $kcalLabelText. Tap to open your diary.',
                excludeSemantics: true,
                child: CircularPercentIndicator(
                  radius: 80,
                  lineWidth: 14,
                  percent: gaugeValue.clamp(0.0, 1.0),
                  animation: true,
                  animationDuration: 800,
                  curve: AppMotion.emphasized,
                  circularStrokeCap: CircularStrokeCap.round,
                  backgroundColor: palette.surfaceMuted,
                  progressColor: palette.accent,
                  center: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedFlipCounter(
                        duration: const Duration(milliseconds: 800),
                        curve: AppMotion.emphasized,
                        value: displayValue.toInt(),
                        textStyle: textTheme.displayMedium?.copyWith(height: 1),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        kcalLabelText,
                        style: textTheme.bodyMedium?.copyWith(
                          color: palette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: Dimens.spacing16),
            Row(
              children: [
                Expanded(
                  child: _MacroRingTile(
                    label: S.of(context).carbsLabel,
                    intake: widget.totalCarbsIntake,
                    goal: widget.totalCarbsGoal,
                    color: palette.carbsColor,
                    palette: palette,
                  ),
                ),
                Expanded(
                  child: _MacroRingTile(
                    label: S.of(context).fatLabel,
                    intake: widget.totalFatsIntake,
                    goal: widget.totalFatsGoal,
                    color: palette.fatColor,
                    palette: palette,
                  ),
                ),
                Expanded(
                  child: _MacroRingTile(
                    label: S.of(context).proteinLabel,
                    intake: widget.totalProteinsIntake,
                    goal: widget.totalProteinsGoal,
                    color: palette.proteinColor,
                    palette: palette,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final bool trailing;

  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.trailing = false,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: trailing
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 6),
        Text(value, style: textTheme.titleMedium),
        Text(label, style: textTheme.labelSmall),
      ],
    );
  }
}

/// A macro's progress as its own small ring instead of a flat bar — reads
/// at a glance next to the two others, and echoes the big ring above it
/// instead of switching visual language halfway down the card.
class _MacroRingTile extends StatelessWidget {
  final String label;
  final double intake;
  final double goal;
  final Color color;
  final AppPalette palette;

  const _MacroRingTile({
    required this.label,
    required this.intake,
    required this.goal,
    required this.color,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (goal <= 0) ? 0.0 : (intake / goal).clamp(0.0, 1.0);
    final left = (goal - intake).clamp(0, goal).round();
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        CircularPercentIndicator(
          radius: 36,
          lineWidth: 7,
          percent: pct,
          animation: true,
          animationDuration: 700,
          curve: AppMotion.emphasized,
          circularStrokeCap: CircularStrokeCap.round,
          backgroundColor: palette.surfaceMuted,
          progressColor: color,
          // Grams left, not a percentage — the number itself is the useful
          // fact, so the ring can carry it directly instead of needing a
          // separate "Xg / Yg" line underneath. The ring fill still shows
          // progress toward the goal (intake/goal).
          center: Text(
            '${left}g',
            style: textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: Dimens.spacing8),
        // "left" spelled out here, at full size and contrast, rather than
        // crammed into the ring itself — a 9px caption squeezed next to the
        // bold number inside a 58px ring wasn't actually legible.
        Text('$label left', style: textTheme.labelMedium),
      ],
    );
  }
}
