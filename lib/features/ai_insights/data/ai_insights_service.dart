import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_activity_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_kcal_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_macro_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_user_activity_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_user_usecase.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/features/ai_insights/domain/insights_aggregation.dart';
import 'package:opennutritracker/core/domain/entity/user_pal_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_weight_goal_entity.dart';
import 'package:opennutritracker/features/ai_insights/data/ai_insights_cache_store.dart';
import 'package:opennutritracker/features/ai_insights/data/coach_prompt_store.dart';
import 'package:opennutritracker/features/ai_provider/data/ai_provider_config_store.dart';
import 'package:opennutritracker/features/ai_provider/data/http_llm_providers.dart';
import 'package:opennutritracker/features/ai_provider/domain/llm_provider.dart';

class AiInsightsService {
  AiInsightsService(
    this._intake,
    this._kcalGoal,
    this._macroGoal,
    this._user,
    this._configStore,
    this._providerFactory,
    this._cache,
    this._activity,
    this._promptStore,
    this._aggregator,
    this._trackedDay,
  );
  final GetIntakeUsecase _intake;
  final GetKcalGoalUsecase _kcalGoal;
  final GetMacroGoalUsecase _macroGoal;
  final GetUserUsecase _user;
  final AiProviderConfigStore _configStore;
  final LlmProviderFactory _providerFactory;
  final AiInsightsCacheStore _cache;
  final GetUserActivityUsecase _activity;
  final CoachPromptStore _promptStore;
  final InsightsAggregator _aggregator;
  final GetTrackedDayUsecase _trackedDay;

  /// How far back the chat looks when someone asks about longer-term
  /// habits. The 7- and 30-day windows come from the diary itself; this
  /// wider one reads the per-day totals, which are cheap to scan and
  /// already carry each day's goal alongside what was actually eaten.
  static const _longRangeDays = 180;

  /// The built-in coaching instruction, shown to the user as the starting
  /// point when they open the prompt editor and used whenever they haven't
  /// saved an override. Explicitly steers away from restating numbers the
  /// diary already shows — "you ate 40g protein" is not insight, it's a
  /// readout, and re-reading it back to the user in a coach message reads
  /// as filler rather than help.
  static const defaultReviewInstruction =
      '''You are CalT, a concise and practical nutrition coach. Review only this person's TODAY'S logged meals and activity. Do not restate totals, grams, or kcal figures the person can already see in their diary — every point must add something they could not already tell from glancing at the numbers: a pattern across meals (timing, combination, repetition), a food-choice tradeoff, or a consequence of what/how they ate that isn't obvious from the raw figures. Be direct but non-judgmental.

Answer exactly three short bullet points, each no more than 28 words: one non-obvious positive observation about today's pattern, one non-obvious nutrition or activity gap or risk (not just "low in X"), and one realistic improvement using specific foods or activities. Do not use headings, labels, generic encouragement, diagnoses, medical claims, or advice based on meals not logged.''';

  /// Appended after whichever instruction is active (default or the
  /// user's own) so the one-line takeaway is always requested even if
  /// someone rewrites the main instruction — it's a fixed output-format
  /// requirement, not part of the coaching persona/tone itself.
  static const _summaryLineInstruction =
      '\n\nAfter the three bullet points, add one final line starting with '
      'exactly "SUMMARY:" followed by a short, natural-language takeaway in '
      'six words or fewer (for example: SUMMARY: Eating well, could use '
      'more protein) that sums up today\'s overall picture at a glance — a '
      'real phrase, not a copy of one of the bullet points. No markdown or '
      'quotes around it.';

  Future<AiInsightsResult?> cachedForToday() async {
    final cached = await _cache.read();
    if (cached == null) {
      return null;
    }
    final now = DateTime.now();
    return cached.generatedAt.year == now.year &&
            cached.generatedAt.month == now.month &&
            cached.generatedAt.day == now.day
        ? cached
        : null;
  }

  Future<AiInsightsResult> generate({bool force = false}) async {
    if (!force) {
      final cached = await cachedForToday();
      if (cached != null) return cached;
    }
    final config = await _configStore.read();
    if (!config.isConfigured) {
      throw const LlmException('No AI provider configured.');
    }
    final todayEntries = await _todayEntries();
    final todayActivities = await _todayActivities();
    final user = await _user.getUserData();
    final kcalGoal = await _kcalGoal.getKcalGoal();
    final macroGoals = [
      await _macroGoal.getProteinsGoal(kcalGoal),
      await _macroGoal.getCarbsGoal(kcalGoal),
      await _macroGoal.getFatsGoal(kcalGoal),
    ];
    final customInstruction = await _promptStore.read();
    final rawText = (await _providerFactory
            .create(config)
            .sendTextPrompt(
              _todayReviewPrompt(
                todayEntries,
                todayActivities,
                kcalGoal,
                macroGoals,
                user,
                customInstruction,
              ),
            ))
        .rawText
        .trim();
    final (text: bulletText, summary: summary) = _splitSummaryLine(rawText);
    final result = AiInsightsResult(
      text: bulletText,
      summary: summary,
      generatedAt: DateTime.now(),
    );
    if (result.text.isEmpty) {
      throw const LlmException('The AI provider returned an empty insight.');
    }
    await _cache.save(result);
    return result;
  }

  /// Splits a review into its individual points, stripping whatever list
  /// syntax the model happened to use. Models reach for markdown even when
  /// the instruction doesn't ask for it — `*` and `-` bullets, sometimes a
  /// numbered list, sometimes `**bold**` around the lead-in — and the
  /// review is rendered as plain text beside our own bullet icons, so any
  /// leftover marker shows up verbatim on screen as "* Pairing tofu...".
  static List<String> bulletPoints(String raw) {
    // A single `*` is a bullet; a doubled one opens markdown bold, so it is
    // left for the emphasis strip below rather than eaten as a marker.
    final marker = RegExp(r'^\s*(?:[-•–—]+|\*(?!\*)|\d+[.)])\s*');
    final emphasis = RegExp(r'(\*\*|__)');
    return raw
        .split(RegExp(r'\r?\n'))
        .map((line) => line.replaceFirst(marker, '').replaceAll(emphasis, '').trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  /// Pulls the "SUMMARY: ..." line requested by [_summaryLineInstruction]
  /// out of the raw response, leaving the three bullet points on their own
  /// (that's what the Coach screen's "Today's review" section renders —
  /// a stray fourth line would show up there as an unlabelled bullet).
  static ({String text, String? summary}) _splitSummaryLine(String raw) {
    final summaryPattern = RegExp(r'^SUMMARY:\s*(.+)$', caseSensitive: false);
    String? summary;
    final bulletLines = <String>[];
    for (final line in raw.split(RegExp(r'\r?\n'))) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;
      final match = summaryPattern.firstMatch(trimmedLine);
      if (match != null) {
        summary = match.group(1)?.trim();
      } else {
        bulletLines.add(line);
      }
    }
    return (text: bulletLines.join('\n').trim(), summary: summary);
  }

  Future<String> answerQuestion(String question) async {
    final trimmed = question.trim();
    if (trimmed.isEmpty) {
      throw const LlmException('Type or dictate a question first.');
    }
    final config = await _configStore.read();
    if (!config.isConfigured) {
      throw const LlmException('No AI provider configured.');
    }
    final user = await _user.getUserData();
    final kcalGoal = await _kcalGoal.getKcalGoal();
    final macroGoals = [
      await _macroGoal.getProteinsGoal(kcalGoal),
      await _macroGoal.getCarbsGoal(kcalGoal),
      await _macroGoal.getFatsGoal(kcalGoal),
    ];
    final customInstruction = await _promptStore.read();
    final persona =
        (customInstruction != null && customInstruction.trim().isNotEmpty)
        ? customInstruction.trim()
        : 'You are CalT, a practical nutrition coach.';
    final now = DateTime.now();
    final history = await _intake.getIntakeByDateRange(
      now.subtract(const Duration(days: 29)),
      now,
    );
    final trackedDays = await _trackedDay.getTrackedDaysByRange(
      DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: _longRangeDays - 1)),
      now,
    );
    final patterns = _aggregator.aggregate(history, now);

    final response = await _providerFactory.create(config).sendTextPrompt(
      '''$persona Answer the user's question using the profile, targets and diary history below. Be concise, specific and helpful. Do not diagnose or make medical claims. Do not use markdown.

The question may be about today, about a recent stretch of days, or about their habits over months. Read it and use whichever window it actually asks about — today's meals for "what should I eat tonight", the 7- or 30-day summary for "how has my week been", the longer history for "am I consistent" or "has anything changed". When you cite a pattern, say which period it comes from so they know what you looked at. Days with nothing logged are gaps in the record, not days of eating nothing — never treat a missing day as a zero, and if a period is too sparse to support an answer, say so instead of inferring a trend from a handful of days.

${_profileContext(user, kcalGoal, macroGoals)}
${_todayDiaryContext(await _todayEntries())}
${_todayActivityContext(await _todayActivities())}
${_periodContext('Last 7 days', patterns.last7Days)}
${_periodContext('Last 30 days', patterns.last30Days)}
${_longRangeContext(trackedDays)}

User question: $trimmed''',
    );
    final text = response.rawText.trim();
    if (text.isEmpty) {
      throw const LlmException('The AI provider returned an empty answer.');
    }
    return text;
  }

  /// A 7- or 30-day window rendered as averages rather than raw rows.
  ///
  /// Averages are over *logged* days, not calendar days — someone who
  /// tracked four days out of seven eats an average over those four, and
  /// dividing by seven would invent a deficit that never happened. The
  /// logged-day count is stated so the model can judge how much the
  /// numbers are worth.
  String _periodContext(String label, NutritionPeriodSummary summary) {
    if (summary.loggedDays == 0) {
      return '$label: nothing logged.';
    }
    final logged = summary.loggedDays;
    String perDay(double total) => (total / logged).round().toString();
    final meals = summary.mealCounts.entries
        .where((entry) => entry.value > 0)
        .map((entry) => '${_mealTypeLabel(entry.key)} ${entry.value}')
        .join(', ');
    final foods = summary.foodNames.isEmpty
        ? ''
        : '\nFoods logged in this period: ${summary.foodNames.join(', ')}.';
    return '$label ($logged of ${summary.days} days logged): '
        'average per logged day ${perDay(summary.kcal)} kcal, '
        '${perDay(summary.carbs)}g carbs, ${perDay(summary.protein)}g protein, '
        '${perDay(summary.fat)}g fat.'
        '${meals.isEmpty ? '' : '\nMeals recorded: $meals.'}$foods';
  }

  /// The long tail, read from per-day totals so it stays cheap. Each day
  /// carries the goal that applied at the time, which is what makes
  /// "am I consistent" answerable rather than guesswork.
  String _longRangeContext(List<TrackedDayEntity> days) {
    final logged = days.where((day) => day.caloriesTracked > 0).toList();
    if (logged.isEmpty) {
      return 'Longer history: nothing logged in the last $_longRangeDays days.';
    }
    logged.sort((a, b) => a.day.compareTo(b.day));
    final kcal = logged.fold<double>(0, (sum, day) => sum + day.caloriesTracked);
    final onTarget = logged
        .where(
          (day) =>
              day.calorieGoal > 0 &&
              (day.caloriesTracked - day.calorieGoal).abs() /
                      day.calorieGoal <=
                  0.1,
        )
        .length;
    final first = logged.first.day;
    final span = DateTime.now().difference(first).inDays + 1;
    return 'Longer history: ${logged.length} days logged since '
        '${first.year}-${first.month.toString().padLeft(2, '0')}-'
        '${first.day.toString().padLeft(2, '0')} '
        '(a $span-day span, within the last $_longRangeDays days). '
        'Average ${(kcal / logged.length).round()} kcal per logged day. '
        '$onTarget of those days landed within 10% of that day\'s calorie goal.';
  }

  String _mealTypeLabel(IntakeTypeEntity type) => switch (type) {
    IntakeTypeEntity.breakfast => 'breakfast',
    IntakeTypeEntity.lunch => 'lunch',
    IntakeTypeEntity.dinner => 'dinner',
    IntakeTypeEntity.snack => 'snacks',
  };

  Future<List<IntakeEntity>> _todayEntries() async {
    final now = DateTime.now();
    final futures = <Future<List<IntakeEntity>>>[];
    final day = DateTime(now.year, now.month, now.day);
    futures.add(_intake.getBreakfastIntakeByDay(day));
    futures.add(_intake.getLunchIntakeByDay(day));
    futures.add(_intake.getDinnerIntakeByDay(day));
    futures.add(_intake.getSnackIntakeByDay(day));
    return (await Future.wait(futures)).expand((entries) => entries).toList();
  }

  Future<List<UserActivityEntity>> _todayActivities() =>
      _activity.getTodayUserActivity();

  String _todayReviewPrompt(
    List<IntakeEntity> entries,
    List<UserActivityEntity> activities,
    double kcalGoal,
    List<double> macroGoals,
    UserEntity user,
    String? customInstruction,
  ) {
    final instruction =
        (customInstruction != null && customInstruction.trim().isNotEmpty)
        ? customInstruction.trim()
        : defaultReviewInstruction;
    return '''$instruction$_summaryLineInstruction

${_profileContext(user, kcalGoal, macroGoals)}
${_todayDiaryContext(entries)}
${_todayActivityContext(activities)}''';
  }

  String _profileContext(
    UserEntity user,
    double kcalGoal,
    List<double> macroGoals,
  ) {
    final goal = switch (user.goal) {
      UserWeightGoalEntity.loseWeight => 'lose weight',
      UserWeightGoalEntity.maintainWeight => 'maintain weight',
      UserWeightGoalEntity.gainWeight => 'gain weight',
    };
    final activity = switch (user.pal) {
      UserPALEntity.sedentary => 'mostly sedentary',
      UserPALEntity.lowActive => 'lightly active',
      UserPALEntity.active => 'active',
      UserPALEntity.veryActive => 'very active',
    };
    return 'Person: age ${user.age}, height ${user.heightCM.toStringAsFixed(0)} cm, weight ${user.weightKG.toStringAsFixed(1)} kg, activity $activity, goal $goal${user.targetWeightKg == null ? '' : ', target weight ${user.targetWeightKg!.toStringAsFixed(1)} kg'}. Daily targets: ${kcalGoal.toStringAsFixed(0)} kcal, protein ${macroGoals[0].toStringAsFixed(0)}g, carbs ${macroGoals[1].toStringAsFixed(0)}g, fat ${macroGoals[2].toStringAsFixed(0)}g.';
  }

  String _todayDiaryContext(List<IntakeEntity> entries) {
    if (entries.isEmpty) return 'Today\'s diary: no meals logged.';
    final kcal = entries.fold<double>(0, (sum, entry) => sum + entry.totalKcal);
    final protein = entries.fold<double>(
      0,
      (sum, entry) => sum + entry.totalProteinsGram,
    );
    final carbs = entries.fold<double>(
      0,
      (sum, entry) => sum + entry.totalCarbsGram,
    );
    final fat = entries.fold<double>(
      0,
      (sum, entry) => sum + entry.totalFatsGram,
    );
    final meals = entries
        .map(
          (entry) =>
              '${entry.type.name}: ${entry.meal.name ?? 'Unnamed meal'} '
              '(${entry.totalKcal.toStringAsFixed(0)} kcal, '
              '${entry.totalProteinsGram.toStringAsFixed(0)}g protein)',
        )
        .join('; ');
    return 'Today\'s diary: $meals. Totals: ${kcal.toStringAsFixed(0)} kcal, '
        '${protein.toStringAsFixed(0)}g protein, ${carbs.toStringAsFixed(0)}g carbs, ${fat.toStringAsFixed(0)}g fat.';
  }

  String _todayActivityContext(List<UserActivityEntity> activities) {
    if (activities.isEmpty) {
      return 'Today\'s activity: no exercise logged.';
    }
    final kcal = activities.fold<double>(
      0,
      (sum, a) => sum + a.effectiveBurnedKcal,
    );
    final lines = activities
        .map((a) {
          final source = a.source == 'healthConnect'
              ? 'synced from Health Connect'
              : 'logged manually';
          return '${a.duration.toStringAsFixed(0)} min '
              '${a.physicalActivityEntity.specificActivity} '
              '(${a.effectiveBurnedKcal.toStringAsFixed(0)} kcal, $source)';
        })
        .join('; ');
    return 'Today\'s activity: $lines. '
        'Total burned: ${kcal.toStringAsFixed(0)} kcal.';
  }
}
