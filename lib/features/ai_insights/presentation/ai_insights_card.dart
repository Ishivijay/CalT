import 'package:flutter/material.dart';
import 'package:opennutritracker/core/presentation/widgets/app_card.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/ai_insights/data/ai_insights_service.dart';
import 'package:opennutritracker/features/ai_insights/presentation/coach_screen.dart';

/// The Home entry point into CalT Coach — a one-line summary of today's
/// review when one exists, otherwise a plain invite. Tapping always opens
/// the full Coach screen; this card itself stays a single line so it
/// doesn't turn back into the noisy multi-state preview it used to be.
class AiInsightsCard extends StatefulWidget {
  const AiInsightsCard({super.key});

  @override
  State<AiInsightsCard> createState() => _AiInsightsCardState();
}

class _AiInsightsCardState extends State<AiInsightsCard> {
  String? _summaryLine;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cached = await locator<AiInsightsService>().cachedForToday();
    if (!mounted || cached == null) return;
    // The service asks the model for its own one-line natural-language
    // takeaway ("SUMMARY: Eating well, could use more protein") alongside
    // the three bullet points, specifically so this card can show a real
    // summary instead of a mechanically truncated bullet. Fall back to a
    // truncated first point only for cache entries from before that field
    // existed, or the rare response that omitted it.
    final line = cached.summary ?? _firstPointFallback(cached.text);
    if (line != null && line.isNotEmpty) {
      setState(() => _summaryLine = line);
    }
  }

  static String? _firstPointFallback(String reviewText) {
    final points = reviewText
        .split(RegExp(r'\r?\n'))
        .map((line) => line.replaceFirst(RegExp(r'^[-•]\s*'), '').trim())
        .where((line) => line.isNotEmpty)
        .toList();
    return points.isEmpty ? null : points.first;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? AppPalette.dark : AppPalette.light;
    final accent = Theme.of(context).colorScheme.primary;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: AppCard(
        borderRadius: Dimens.radiusL,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const CoachScreen()))
            .then((_) => _load()),
        child: Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: accent, size: 22),
            const SizedBox(width: Dimens.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CalT Coach', style: textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    _summaryLine ?? 'Tap for today\'s review & chat',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(color: palette.textMuted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: palette.textMuted),
          ],
        ),
      ),
    );
  }
}
