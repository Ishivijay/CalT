import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_kcal_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_macro_goal_usecase.dart';
import 'package:opennutritracker/features/ai_insights/data/ai_insights_cache_store.dart';
import 'package:opennutritracker/features/ai_insights/domain/insights_aggregation.dart';
import 'package:opennutritracker/features/ai_provider/data/ai_provider_config_store.dart';
import 'package:opennutritracker/features/ai_provider/data/http_llm_providers.dart';
import 'package:opennutritracker/features/ai_provider/domain/llm_provider.dart';

class AiInsightsService {
  AiInsightsService(this._intake, this._kcalGoal, this._macroGoal, this._configStore, this._providerFactory, this._cache, this._aggregator);
  final GetIntakeUsecase _intake; final GetKcalGoalUsecase _kcalGoal; final GetMacroGoalUsecase _macroGoal;
  final AiProviderConfigStore _configStore; final LlmProviderFactory _providerFactory; final AiInsightsCacheStore _cache; final InsightsAggregator _aggregator;

  Future<AiInsightsResult?> cachedForToday() async {
    final cached = await _cache.read();
    if (cached == null) return null;
    final now = DateTime.now();
    return cached.generatedAt.year == now.year && cached.generatedAt.month == now.month && cached.generatedAt.day == now.day ? cached : null;
  }

  Future<AiInsightsResult> generate({bool force = false}) async {
    if (!force) { final cached = await cachedForToday(); if (cached != null) return cached; }
    final config = await _configStore.read();
    if (!config.isConfigured) throw const LlmException('No AI provider configured.');
    final aggregation = _aggregator.aggregate(await _recentEntries(), DateTime.now());
    final kcalGoal = await _kcalGoal.getKcalGoal();
    final macroGoals = [
      await _macroGoal.getProteinsGoal(kcalGoal),
      await _macroGoal.getCarbsGoal(kcalGoal),
      await _macroGoal.getFatsGoal(kcalGoal),
    ];
    final result = AiInsightsResult(text: (await _providerFactory.create(config).sendTextPrompt(_prompt(aggregation, kcalGoal, macroGoals))).rawText.trim(), generatedAt: DateTime.now());
    if (result.text.isEmpty) throw const LlmException('The AI provider returned an empty insight.');
    await _cache.save(result);
    return result;
  }

  Future<List<IntakeEntity>> _recentEntries() async {
    final now = DateTime.now(); final futures = <Future<List<IntakeEntity>>>[];
    for (var offset = 0; offset < 30; offset++) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: offset));
      futures.add(_intake.getBreakfastIntakeByDay(day)); futures.add(_intake.getLunchIntakeByDay(day)); futures.add(_intake.getDinnerIntakeByDay(day)); futures.add(_intake.getSnackIntakeByDay(day));
    }
    return (await Future.wait(futures)).expand((entries) => entries).toList();
  }

  String _prompt(InsightsAggregation data, double kcalGoal, List<double> macroGoals) {
    String period(String label, NutritionPeriodSummary p) => '$label: ${p.loggedDays}/${p.days} days logged; average ${p.kcalDailyAverage.toStringAsFixed(0)} kcal/day; protein ${p.proteinDailyAverage.toStringAsFixed(0)}g/day; totals carbs ${p.carbs.toStringAsFixed(0)}g, fat ${p.fat.toStringAsFixed(0)}g; meals breakfast ${p.mealCounts[IntakeTypeEntity.breakfast]}, lunch ${p.mealCounts[IntakeTypeEntity.lunch]}, dinner ${p.mealCounts[IntakeTypeEntity.dinner]}, snack ${p.mealCounts[IntakeTypeEntity.snack]}.';
    return '''You are a supportive nutrition diary assistant. Based only on these aggregate diary totals, write a short natural-language overview, 2–3 concrete non-judgmental suggestions, and one thing the person is doing well. Daily targets: ${kcalGoal.toStringAsFixed(0)} kcal, protein ${macroGoals[0].toStringAsFixed(0)}g, carbs ${macroGoals[1].toStringAsFixed(0)}g, fat ${macroGoals[2].toStringAsFixed(0)}g. ${period('Last 7 days', data.last7Days)} ${period('Last 30 days', data.last30Days)}. Do not diagnose conditions, make clinical claims, or present this as medical advice.''';
  }
}
