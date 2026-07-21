import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_kcal_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_macro_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_user_usecase.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_pal_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_weight_goal_entity.dart';
import 'package:opennutritracker/features/ai_insights/data/ai_insights_cache_store.dart';
import 'package:opennutritracker/features/ai_insights/domain/insights_aggregation.dart';
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
    this._aggregator,
  );
  final GetIntakeUsecase _intake;
  final GetKcalGoalUsecase _kcalGoal;
  final GetMacroGoalUsecase _macroGoal;
  final GetUserUsecase _user;
  final AiProviderConfigStore _configStore;
  final LlmProviderFactory _providerFactory;
  final AiInsightsCacheStore _cache;
  final InsightsAggregator _aggregator;

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
    final aggregation = _aggregator.aggregate(
      await _recentEntries(),
      DateTime.now(),
    );
    final user = await _user.getUserData();
    final kcalGoal = await _kcalGoal.getKcalGoal();
    final macroGoals = [
      await _macroGoal.getProteinsGoal(kcalGoal),
      await _macroGoal.getCarbsGoal(kcalGoal),
      await _macroGoal.getFatsGoal(kcalGoal),
    ];
    final result = AiInsightsResult(
      text:
          (await _providerFactory
                  .create(config)
                  .sendTextPrompt(
                    _prompt(aggregation, kcalGoal, macroGoals, user),
                  ))
              .rawText
              .trim(),
      generatedAt: DateTime.now(),
    );
    if (result.text.isEmpty) {
      throw const LlmException('The AI provider returned an empty insight.');
    }
    await _cache.save(result);
    return result;
  }

  Future<List<IntakeEntity>> _recentEntries() async {
    final now = DateTime.now();
    final futures = <Future<List<IntakeEntity>>>[];
    for (var offset = 0; offset < 30; offset++) {
      final day = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: offset));
      futures.add(_intake.getBreakfastIntakeByDay(day));
      futures.add(_intake.getLunchIntakeByDay(day));
      futures.add(_intake.getDinnerIntakeByDay(day));
      futures.add(_intake.getSnackIntakeByDay(day));
    }
    return (await Future.wait(futures)).expand((entries) => entries).toList();
  }

  String _prompt(
    InsightsAggregation data,
    double kcalGoal,
    List<double> macroGoals,
    UserEntity user,
  ) {
    String period(String label, NutritionPeriodSummary p) =>
        '$label: ${p.loggedDays}/${p.days} days logged; average ${p.kcalDailyAverage.toStringAsFixed(0)} kcal/day; protein ${p.proteinDailyAverage.toStringAsFixed(0)}g/day; carbs ${p.carbs.toStringAsFixed(0)}g total; fat ${p.fat.toStringAsFixed(0)}g total; meal counts breakfast ${p.mealCounts[IntakeTypeEntity.breakfast]}, lunch ${p.mealCounts[IntakeTypeEntity.lunch]}, dinner ${p.mealCounts[IntakeTypeEntity.dinner]}, snack ${p.mealCounts[IntakeTypeEntity.snack]}; logged foods: ${p.foodNames.isEmpty ? 'none' : p.foodNames.join(', ')}.';
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
    return '''You are CalT, a concise and practical nutrition coach. Personalize the response to this exact person and their ACTUAL food diary. Person: age ${user.age}, height ${user.heightCM.toStringAsFixed(0)} cm, weight ${user.weightKG.toStringAsFixed(1)} kg, activity level $activity, stated goal $goal${user.targetWeightKg == null ? '' : ', target weight ${user.targetWeightKg!.toStringAsFixed(1)} kg'}. Daily targets: ${kcalGoal.toStringAsFixed(0)} kcal, protein ${macroGoals[0].toStringAsFixed(0)}g, carbs ${macroGoals[1].toStringAsFixed(0)}g, fat ${macroGoals[2].toStringAsFixed(0)}g.

Return no more than 90 words in exactly three plain-text lines:
TODAY: one highly specific observation about current or recent intake versus this person's goal.
PATTERN: one specific pattern from the logged foods, protein timing, energy, or consistency.
NEXT: one small, realistic next food choice or logging action tailored to this person's goal.

Do not use generic encouragement, bullets, markdown, diagnoses, medical claims, or invented nutrients. If the diary is sparse, say that directly and only comment on the actual logged foods.

${period('Last 7 days', data.last7Days)}
${period('Last 30 days', data.last30Days)}''';
  }
}
