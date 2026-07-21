import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_kcal_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_macro_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_user_usecase.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_pal_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_weight_goal_entity.dart';
import 'package:opennutritracker/features/ai_insights/data/ai_insights_cache_store.dart';
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
  );
  final GetIntakeUsecase _intake;
  final GetKcalGoalUsecase _kcalGoal;
  final GetMacroGoalUsecase _macroGoal;
  final GetUserUsecase _user;
  final AiProviderConfigStore _configStore;
  final LlmProviderFactory _providerFactory;
  final AiInsightsCacheStore _cache;

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
                    _todayReviewPrompt(
                      todayEntries,
                      kcalGoal,
                      macroGoals,
                      user,
                    ),
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
    final response = await _providerFactory.create(config).sendTextPrompt(
      '''You are CalT, a practical nutrition coach. Answer the user's question using their exact profile, goal, targets, and TODAY'S logged meals below. Be concise, specific, and helpful. Do not diagnose or make medical claims. If the diary does not contain the information needed, say so clearly. Do not use markdown.

${_profileContext(user, kcalGoal, macroGoals)}
${_todayDiaryContext(await _todayEntries())}

User question: $trimmed''',
    );
    final text = response.rawText.trim();
    if (text.isEmpty) {
      throw const LlmException('The AI provider returned an empty answer.');
    }
    return text;
  }

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

  String _todayReviewPrompt(
    List<IntakeEntity> entries,
    double kcalGoal,
    List<double> macroGoals,
    UserEntity user,
  ) {
    return '''You are CalT, a concise and practical nutrition coach. Review only this person's TODAY'S logged meals. Explain what was good for their health or goal, what is missing or unbalanced, and one or two realistic improvements using specific foods. Be direct but non-judgmental.

${_profileContext(user, kcalGoal, macroGoals)}
${_todayDiaryContext(entries)}

Return exactly three short bullet points, each no more than 28 words: one specific positive, one specific nutrition gap, and one realistic improvement. Do not use headings, labels, generic encouragement, diagnoses, medical claims, or advice based on meals not logged.''';
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
}
