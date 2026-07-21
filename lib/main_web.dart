import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:opennutritracker/features/ai_provider/data/http_llm_providers.dart';
import 'package:opennutritracker/features/ai_provider/domain/ai_provider_config.dart';
import 'package:opennutritracker/features/ai_provider/domain/llm_provider.dart';

void main() => runApp(const NutritionWebApp());

class NutritionWebApp extends StatelessWidget {
  const NutritionWebApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'OpenNutriTracker Web',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff287a54),
        brightness: Brightness.light,
        surface: const Color(0xfffbfdf9),
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xfff4f7f2),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xffdfe9df)),
        ),
      ),
      appBarTheme: const AppBarThemeData(
        backgroundColor: Color(0xfff4f7f2),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
    ),
    home: const NutritionWebHome(),
  );
}

class _WebMeal {
  const _WebMeal({
    required this.name,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.grams,
    required this.createdAt,
  });
  final String name;
  final double kcal, protein, carbs, fat, grams;
  final DateTime createdAt;
  Map<String, dynamic> toJson() => {
    'name': name,
    'kcal': kcal,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'grams': grams,
    'createdAt': createdAt.toIso8601String(),
  };
  factory _WebMeal.fromJson(Map<String, dynamic> json) => _WebMeal(
    name: json['name']?.toString() ?? 'Meal',
    kcal: _number(json['kcal']),
    protein: _number(json['protein']),
    carbs: _number(json['carbs']),
    fat: _number(json['fat']),
    grams: _number(json['grams']),
    createdAt:
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime.now(),
  );
}

class _AiItem {
  const _AiItem({
    required this.name,
    required this.grams,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
  });
  final String name;
  final double grams, kcal, protein, carbs, fat;
  _AiItem copyWith({
    String? name,
    double? grams,
    double? kcal,
    double? protein,
    double? carbs,
    double? fat,
  }) => _AiItem(
    name: name ?? this.name,
    grams: grams ?? this.grams,
    kcal: kcal ?? this.kcal,
    protein: protein ?? this.protein,
    carbs: carbs ?? this.carbs,
    fat: fat ?? this.fat,
  );
}

class _PersonProfile {
  const _PersonProfile({
    this.name = '',
    this.age = '',
    this.sex = '',
    this.heightCm = '',
    this.weightKg = '',
    this.activityLevel = '',
    this.goal = '',
    this.dietaryPreferences = '',
    this.healthContext = '',
  });

  static const empty = _PersonProfile();

  final String name;
  final String age;
  final String sex;
  final String heightCm;
  final String weightKg;
  final String activityLevel;
  final String goal;
  final String dietaryPreferences;
  final String healthContext;

  bool get hasDetails => [
    age,
    sex,
    heightCm,
    weightKg,
    activityLevel,
    goal,
    dietaryPreferences,
    healthContext,
  ].any((value) => value.trim().isNotEmpty);

  Map<String, dynamic> toJson() => {
    'name': name,
    'age': age,
    'sex': sex,
    'heightCm': heightCm,
    'weightKg': weightKg,
    'activityLevel': activityLevel,
    'goal': goal,
    'dietaryPreferences': dietaryPreferences,
    'healthContext': healthContext,
  };

  factory _PersonProfile.fromJson(Map<String, dynamic> json) => _PersonProfile(
    name: json['name']?.toString() ?? '',
    age: json['age']?.toString() ?? '',
    sex: json['sex']?.toString() ?? '',
    heightCm: json['heightCm']?.toString() ?? '',
    weightKg: json['weightKg']?.toString() ?? '',
    activityLevel: json['activityLevel']?.toString() ?? '',
    goal: json['goal']?.toString() ?? '',
    dietaryPreferences: json['dietaryPreferences']?.toString() ?? '',
    healthContext: json['healthContext']?.toString() ?? '',
  );

  String get promptContext =>
      '''PERSON PROFILE (optional context supplied by the person):
Age: ${age.trim().isEmpty ? 'not provided' : age.trim()}
Sex: ${sex.trim().isEmpty ? 'not provided' : sex.trim()}
Height: ${heightCm.trim().isEmpty ? 'not provided' : '${heightCm.trim()} cm'}
Weight: ${weightKg.trim().isEmpty ? 'not provided' : '${weightKg.trim()} kg'}
Activity level: ${activityLevel.trim().isEmpty ? 'not provided' : activityLevel.trim()}
Goal: ${goal.trim().isEmpty ? 'not provided' : goal.trim()}
Dietary preferences or restrictions: ${dietaryPreferences.trim().isEmpty ? 'not provided' : dietaryPreferences.trim()}
Health context: ${healthContext.trim().isEmpty ? 'not provided' : healthContext.trim()}
Use this only to tailor general food-pattern observations. Do not diagnose, prescribe, or make claims about medical conditions.''';
}

double _number(dynamic value) => value is num
    ? value.toDouble()
    : double.tryParse(value?.toString() ?? '') ?? 0;

class NutritionWebHome extends StatefulWidget {
  const NutritionWebHome({super.key});
  @override
  State<NutritionWebHome> createState() => _NutritionWebHomeState();
}

class _NutritionWebHomeState extends State<NutritionWebHome> {
  static const _mealKey = 'ont_web_meals_v1';
  static const _configKey = 'ont_web_ai_config_v1';
  static const _profileKey = 'ont_web_profile_v1';
  final _factory = LlmProviderFactory(http.Client());
  List<_WebMeal> _meals = [];
  AiProviderConfig _config = AiProviderConfig.empty;
  _PersonProfile _profile = _PersonProfile.empty;
  Uint8List? _image;
  List<_AiItem> _photoItems = [];
  bool _working = false;
  bool _isDraggingFile = false;
  String? _insight;
  final List<StreamSubscription> _dropSubscriptions = [];

  @override
  void initState() {
    super.initState();
    _load();
    _listenForImageDrops();
  }

  @override
  void dispose() {
    for (final subscription in _dropSubscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  void _load() {
    try {
      final storedMeals = html.window.localStorage[_mealKey];
      final storedConfig = html.window.sessionStorage[_configKey];
      final storedProfile = html.window.localStorage[_profileKey];
      _meals = storedMeals == null
          ? []
          : (jsonDecode(storedMeals) as List)
                .whereType<Map>()
                .map(
                  (item) => _WebMeal.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList();
      _config = storedConfig == null
          ? AiProviderConfig.empty
          : AiProviderConfig.fromJson(
              Map<String, dynamic>.from(jsonDecode(storedConfig) as Map),
            );
      _profile = storedProfile == null
          ? _PersonProfile.empty
          : _PersonProfile.fromJson(
              Map<String, dynamic>.from(jsonDecode(storedProfile) as Map),
            );
    } catch (_) {
      _meals = [];
      _config = AiProviderConfig.empty;
      _profile = _PersonProfile.empty;
    }
  }

  void _saveMeals() => html.window.localStorage[_mealKey] = jsonEncode(
    _meals.map((meal) => meal.toJson()).toList(),
  );
  void _saveConfig() =>
      html.window.sessionStorage[_configKey] = jsonEncode(_config.toJson());
  void _saveProfile() =>
      html.window.localStorage[_profileKey] = jsonEncode(_profile.toJson());

  void _listenForImageDrops() {
    final body = html.document.body;
    if (body == null) return;
    _dropSubscriptions.add(
      body.onDragOver.listen((event) {
        event.preventDefault();
        if (mounted && !_isDraggingFile) setState(() => _isDraggingFile = true);
      }),
    );
    _dropSubscriptions.add(
      body.onDragLeave.listen((event) {
        if (mounted) setState(() => _isDraggingFile = false);
      }),
    );
    _dropSubscriptions.add(
      body.onDrop.listen((event) async {
        event.preventDefault();
        if (mounted) setState(() => _isDraggingFile = false);
        final file = event.dataTransfer.files?.firstOrNull;
        if (file == null) return;
        await _loadImageFile(file);
      }),
    );
    _dropSubscriptions.add(
      html.document.onPaste.listen((event) async {
        final file = event.clipboardData?.files?.firstOrNull;
        if (file == null) return;
        await _loadImageFile(file);
      }),
    );
  }

  Future<void> _selectPhoto() async {
    final input = html.FileUploadInputElement()
      ..accept = 'image/*'
      ..style.display = 'none';
    // Firefox reliably opens a picker only for an input attached to the DOM.
    html.document.body?.append(input);
    try {
      input.click();
      await input.onChange.first;
      final file = input.files?.firstOrNull;
      if (file == null) {
        _show('No photo selected.');
        return;
      }
      await _loadImageFile(file);
    } catch (_) {
      _show('Could not open or read the photo. Try a JPG or PNG file.');
    } finally {
      input.remove();
    }
  }

  Future<void> _loadImageFile(html.File file) async {
    if (!file.type.startsWith('image/')) {
      _show('Drop an image file such as JPG, PNG, or WebP.');
      return;
    }
    try {
      final reader = html.FileReader()..readAsDataUrl(file);
      await reader.onLoadEnd.first;
      final dataUrl = reader.result;
      if (dataUrl is! String || !dataUrl.contains(',') || !mounted) {
        _show('Could not read that image. Try a JPG or PNG file.');
        return;
      }
      setState(() {
        _image = base64Decode(dataUrl.substring(dataUrl.indexOf(',') + 1));
        _photoItems = [];
      });
      _show('Photo ready. Review it, then choose Analyze.');
    } catch (_) {
      _show('Could not read that image. Try a JPG or PNG file.');
    }
  }

  Future<void> _analyzePhoto() async {
    if (_image == null) return;
    if (!_config.isConfigured) {
      _show('Configure an AI provider first.');
      return;
    }
    setState(() => _working = true);
    try {
      final response = await _factory
          .create(_config)
          .sendVisionPrompt(
            imageBytes: _image!,
            promptText:
                '''Analyze this meal image. Return only JSON: {"items":[{"name":"string","estimated_grams":0,"kcal":0,"protein_g":0,"carbs_g":0,"fat_g":0}]}. Estimates may be uncertain; do not give medical advice.''',
          );
      final rawItems = response.json?['items'];
      if (rawItems is! List)
        throw const LlmException('The AI response did not contain meal items.');
      final items = rawItems
          .whereType<Map>()
          .map((raw) => Map<String, dynamic>.from(raw))
          .map(
            (json) => _AiItem(
              name: json['name']?.toString() ?? '',
              grams: _number(json['estimated_grams']),
              kcal: _number(json['kcal']),
              protein: _number(json['protein_g']),
              carbs: _number(json['carbs_g']),
              fat: _number(json['fat_g']),
            ),
          )
          .where((item) => item.name.trim().isNotEmpty)
          .toList();
      if (items.isEmpty)
        throw const LlmException(
          'No foods were identified. Try another photo.',
        );
      if (mounted) setState(() => _photoItems = items);
    } on LlmException catch (error) {
      _show(error.message);
    } catch (_) {
      _show(
        'Could not analyze the photo. Check your provider configuration and try again.',
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _savePhotoItems() {
    setState(() {
      _meals = [
        ..._meals,
        ..._photoItems.map(
          (item) => _WebMeal(
            name: item.name,
            kcal: item.kcal,
            protein: item.protein,
            carbs: item.carbs,
            fat: item.fat,
            grams: item.grams,
            createdAt: DateTime.now(),
          ),
        ),
      ];
      _photoItems = [];
      _image = null;
      _saveMeals();
    });
    _show('Reviewed photo estimates saved to your diary.');
  }

  Future<void> _generateInsights() async {
    if (!_config.isConfigured) {
      _show('Configure an AI provider first.');
      return;
    }
    if (_meals.isEmpty) {
      _show('Add at least one meal before generating diary insights.');
      return;
    }
    setState(() => _working = true);
    try {
      final result = await _factory
          .create(_config)
          .sendTextPrompt(_insightPrompt());
      if (mounted) setState(() => _insight = _cleanInsight(result.rawText));
    } on LlmException catch (error) {
      _show(error.message);
    } catch (_) {
      _show('Could not generate insights.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  String _insightPrompt() {
    // Keep a large diary useful without silently sending an unbounded amount
    // of browser-local data to the selected provider.
    final entries = [..._meals]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final scoped = entries.length <= 100
        ? entries
        : entries.sublist(entries.length - 100);
    final byDay = <String, List<_WebMeal>>{};
    for (final meal in scoped) {
      final day =
          '${meal.createdAt.year}-${meal.createdAt.month.toString().padLeft(2, '0')}-${meal.createdAt.day.toString().padLeft(2, '0')}';
      (byDay[day] ??= []).add(meal);
    }
    final dayLines = byDay.entries
        .map((entry) {
          final meals = entry.value;
          final kcal = meals.fold<double>(0, (sum, meal) => sum + meal.kcal);
          final protein = meals.fold<double>(
            0,
            (sum, meal) => sum + meal.protein,
          );
          final carbs = meals.fold<double>(0, (sum, meal) => sum + meal.carbs);
          final fat = meals.fold<double>(0, (sum, meal) => sum + meal.fat);
          return '${entry.key}: ${meals.length} entries; ${kcal.toStringAsFixed(0)} kcal; protein ${protein.toStringAsFixed(1)}g; carbs ${carbs.toStringAsFixed(1)}g; fat ${fat.toStringAsFixed(1)}g.';
        })
        .join('\n');
    final entryLines = scoped
        .map(
          (meal) =>
              '${meal.createdAt.toIso8601String().substring(0, 10)} | ${meal.name} | ${meal.grams.toStringAsFixed(0)}g | ${meal.kcal.toStringAsFixed(0)} kcal | protein ${meal.protein.toStringAsFixed(1)}g | carbs ${meal.carbs.toStringAsFixed(1)}g | fat ${meal.fat.toStringAsFixed(1)}g',
        )
        .join('\n');
    return '''You are reviewing a nutrition diary. Give specific, useful observations based on the ACTUAL logged foods and numbers below; do not give generic advice about "logging more" unless the data is genuinely too sparse. Do not use Markdown, asterisks, bullet symbols, or a preamble.

Adapt to the amount of data: if it is one meal or one day, analyze that entry and say clearly that it is not a daily pattern. If it spans several days, compare the real day-by-day patterns. Discuss energy and the available macronutrients, and identify food-choice patterns using the food names. Do not claim vitamin/mineral deficiencies or diagnose health conditions, because micronutrients are not logged. Be non-judgmental and practical.

Use exactly these concise plain-text sections:
DIARY SNAPSHOT:
NUTRIENT PATTERN:
FOOD-CHOICE INSIGHTS:
ONE USEFUL NEXT STEP:
DATA LIMIT:

${_profile.promptContext}

Diary coverage: ${scoped.length} entries across ${byDay.length} logged day(s). ${entries.length > scoped.length ? 'Only the latest 100 entries are included.' : ''}

DAY TOTALS:
$dayLines

MEAL ENTRIES:
$entryLines''';
  }

  String _cleanInsight(String text) => text
      .replaceAll('**', '')
      .replaceAll('###', '')
      .replaceAll(RegExp(r'^\s*[-*]\s+', multiLine: true), '')
      .trim();

  void _show(String text) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _editPhotoItem(int index) async {
    final item = _photoItems[index];
    final name = TextEditingController(text: item.name);
    final grams = TextEditingController(text: item.grams.toStringAsFixed(0));
    final kcal = TextEditingController(text: item.kcal.toStringAsFixed(0));
    final protein = TextEditingController(
      text: item.protein.toStringAsFixed(1),
    );
    final carbs = TextEditingController(text: item.carbs.toStringAsFixed(1));
    final fat = TextEditingController(text: item.fat.toStringAsFixed(1));
    final edited = await showDialog<_AiItem>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Review AI estimate'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _input(name, 'Food name'),
              _input(grams, 'Grams'),
              _input(kcal, 'Calories'),
              _input(protein, 'Protein (g)'),
              _input(carbs, 'Carbs (g)'),
              _input(fat, 'Fat (g)'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              item.copyWith(
                name: name.text,
                grams: _number(grams.text),
                kcal: _number(kcal.text),
                protein: _number(protein.text),
                carbs: _number(carbs.text),
                fat: _number(fat.text),
              ),
            ),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    for (final controller in [name, grams, kcal, protein, carbs, fat]) {
      controller.dispose();
    }
    if (edited != null && mounted)
      setState(() => _photoItems = [..._photoItems]..[index] = edited);
  }

  Widget _input(TextEditingController controller, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: controller,
      keyboardType: label == 'Food name'
          ? TextInputType.text
          : const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    ),
  );

  Future<void> _addManualMeal() async {
    final name = TextEditingController();
    final kcal = TextEditingController();
    final protein = TextEditingController();
    final carbs = TextEditingController();
    final fat = TextEditingController();
    final meal = await showDialog<_WebMeal>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add meal'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _input(name, 'Food name'),
              _input(kcal, 'Calories'),
              _input(protein, 'Protein (g)'),
              _input(carbs, 'Carbs (g)'),
              _input(fat, 'Fat (g)'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              _WebMeal(
                name: name.text.trim(),
                kcal: _number(kcal.text),
                protein: _number(protein.text),
                carbs: _number(carbs.text),
                fat: _number(fat.text),
                grams: 100,
                createdAt: DateTime.now(),
              ),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    for (final controller in [name, kcal, protein, carbs, fat]) {
      controller.dispose();
    }
    if (meal != null && meal.name.isNotEmpty)
      setState(() {
        _meals = [..._meals, meal];
        _saveMeals();
      });
  }

  Future<void> _settings() async {
    var provider = _config.provider;
    final model = TextEditingController(text: _config.modelId);
    final key = TextEditingController(text: _config.apiKey);
    final base = TextEditingController(text: _config.baseUrl ?? '');
    final config = await showDialog<AiProviderConfig>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('AI provider (BYOK)'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Your API key is held only for this browser session. Photos and prompts are sent to the provider you choose.',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<AiProviderKind>(
                  value: provider,
                  items: const [
                    DropdownMenuItem(
                      value: AiProviderKind.openAi,
                      child: Text('OpenAI'),
                    ),
                    DropdownMenuItem(
                      value: AiProviderKind.anthropic,
                      child: Text('Anthropic'),
                    ),
                    DropdownMenuItem(
                      value: AiProviderKind.gemini,
                      child: Text('Gemini'),
                    ),
                    DropdownMenuItem(
                      value: AiProviderKind.customOpenAi,
                      child: Text('Custom OpenAI-compatible'),
                    ),
                  ],
                  onChanged: (value) => update(() => provider = value!),
                ),
                const SizedBox(height: 12),
                _input(model, 'Model ID'),
                if (provider == AiProviderKind.customOpenAi)
                  _input(base, 'Base URL'),
                _input(key, 'API key'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                AiProviderConfig(
                  provider: provider,
                  apiKey: key.text,
                  modelId: model.text,
                  baseUrl: base.text,
                ),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    model.dispose();
    key.dispose();
    base.dispose();
    if (config != null)
      setState(() {
        _config = config;
        _saveConfig();
      });
  }

  Future<void> _openProfileAndData() async {
    final profile = await Navigator.of(context).push<_PersonProfile>(
      MaterialPageRoute(
        builder: (context) =>
            _ProfileAndDataScreen(profile: _profile, meals: _meals),
      ),
    );
    if (profile == null || !mounted) return;
    setState(() {
      _profile = profile;
      _saveProfile();
    });
    _show('Profile saved locally. Future AI insights will use it.');
  }

  @override
  Widget build(BuildContext context) {
    final today = _meals
        .where((meal) => DateUtils.isSameDay(meal.createdAt, DateTime.now()))
        .toList();
    final kcal = today.fold<double>(0, (sum, meal) => sum + meal.kcal);
    final protein = today.fold<double>(0, (sum, meal) => sum + meal.protein);
    final carbs = today.fold<double>(0, (sum, meal) => sum + meal.carbs);
    final fat = today.fold<double>(0, (sum, meal) => sum + meal.fat);
    final theme = Theme.of(context);
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
        ? 'Good afternoon'
        : 'Good evening';
    final greetingWithName = _profile.name.trim().isEmpty
        ? greeting
        : '$greeting, ${_profile.name.trim()}';

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.eco_rounded, color: Color(0xff287a54)),
            SizedBox(width: 8),
            Text('NutriTrack'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _openProfileAndData,
            icon: const Icon(Icons.person_outline_rounded),
            tooltip: 'Profile and data',
          ),
          IconButton(
            onPressed: _settings,
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'AI settings',
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addManualMeal,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add meal'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              children: [
                Text(
                  greetingWithName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: const Color(0xff527060),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your food, in focus.',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xffdff2e5),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 24,
                        backgroundColor: Color(0xff287a54),
                        child: Icon(
                          Icons.restaurant_menu_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Today\'s nutrition',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              today.isEmpty
                                  ? 'Start with a meal, a photo, or a quick note.'
                                  : '${today.length} ${today.length == 1 ? 'entry' : 'entries'} logged today.',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _stat(
                      'Calories',
                      '${kcal.toStringAsFixed(0)} kcal',
                      Icons.local_fire_department_rounded,
                      const Color(0xffd96836),
                    ),
                    _stat(
                      'Protein',
                      '${protein.toStringAsFixed(0)} g',
                      Icons.fitness_center_rounded,
                      const Color(0xff5e67a7),
                    ),
                    _stat(
                      'Carbs',
                      '${carbs.toStringAsFixed(0)} g',
                      Icons.grain_rounded,
                      const Color(0xffbd7d22),
                    ),
                    _stat(
                      'Fat',
                      '${fat.toStringAsFixed(0)} g',
                      Icons.water_drop_rounded,
                      const Color(0xff287a54),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                _section(
                  title: 'Photo log',
                  subtitle:
                      'Drop a meal photo anywhere on this page, or select one below.',
                  icon: Icons.camera_alt_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_image == null)
                        _photoDropZone()
                      else ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.memory(
                            _image!,
                            height: 250,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _photoDropZone(compact: true),
                      ],
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _working ? null : _selectPhoto,
                            icon: const Icon(Icons.photo_library_outlined),
                            label: Text(
                              _image == null ? 'Choose photo' : 'Replace photo',
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: _image == null || _working
                                ? null
                                : _analyzePhoto,
                            icon: _working
                                ? const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.auto_awesome_rounded),
                            label: Text(
                              _working ? 'Analyzing…' : 'Analyze meal',
                            ),
                          ),
                        ],
                      ),
                      if (_photoItems.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(
                          'Review estimates',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Tap an item to adjust it before adding it to your diary.',
                        ),
                        const SizedBox(height: 10),
                        for (var i = 0; i < _photoItems.length; i++)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xfff4f8f3),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: ListTile(
                              onTap: () => _editPhotoItem(i),
                              leading: const CircleAvatar(
                                child: Icon(Icons.restaurant_rounded),
                              ),
                              title: Text(_photoItems[i].name),
                              subtitle: Text(
                                '${_photoItems[i].grams.toStringAsFixed(0)} g · ${_photoItems[i].kcal.toStringAsFixed(0)} kcal',
                              ),
                              trailing: IconButton(
                                onPressed: () => setState(
                                  () =>
                                      _photoItems = [..._photoItems]
                                        ..removeAt(i),
                                ),
                                icon: const Icon(Icons.delete_outline_rounded),
                                tooltip: 'Remove item',
                              ),
                            ),
                          ),
                        const SizedBox(height: 4),
                        FilledButton.icon(
                          onPressed: _savePhotoItems,
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Add to diary'),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _section(
                  title: 'AI diary insights',
                  subtitle:
                      'Based only on the meals and macros you have logged.',
                  icon: Icons.auto_graph_rounded,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FilledButton.icon(
                        onPressed: _working ? null : _generateInsights,
                        icon: const Icon(Icons.insights_rounded),
                        label: const Text('Analyze diary'),
                      ),
                      if (_insight != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xfff2f7f1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            _insight!,
                            style: const TextStyle(height: 1.45),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Text(
                      'Today\'s diary',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${today.length} ${today.length == 1 ? 'item' : 'items'}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xff527060),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (today.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xffdfe9df)),
                    ),
                    child: const Column(
                      children: [
                        Icon(
                          Icons.lunch_dining_outlined,
                          size: 36,
                          color: Color(0xff527060),
                        ),
                        SizedBox(height: 10),
                        Text('Nothing logged yet'),
                        SizedBox(height: 4),
                        Text(
                          'Add a meal or use a photo to begin your diary.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                for (final meal in today.reversed) ...[
                  Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xffe2f1e5),
                        child: Icon(
                          Icons.restaurant_rounded,
                          color: Color(0xff287a54),
                        ),
                      ),
                      title: Text(
                        meal.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${meal.grams.toStringAsFixed(0)} g · P ${meal.protein.toStringAsFixed(1)} g · C ${meal.carbs.toStringAsFixed(1)} g · F ${meal.fat.toStringAsFixed(1)} g',
                      ),
                      trailing: Text(
                        '${meal.kcal.toStringAsFixed(0)}\nkcal',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _photoDropZone({bool compact = false}) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    width: double.infinity,
    padding: EdgeInsets.symmetric(vertical: compact ? 14 : 30, horizontal: 18),
    decoration: BoxDecoration(
      color: _isDraggingFile
          ? const Color(0xffdff2e5)
          : const Color(0xfff7faf6),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: _isDraggingFile
            ? const Color(0xff287a54)
            : const Color(0xffbdd7c3),
        width: _isDraggingFile ? 2 : 1,
      ),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _isDraggingFile
              ? Icons.file_download_rounded
              : Icons.add_a_photo_outlined,
          size: compact ? 25 : 34,
          color: const Color(0xff287a54),
        ),
        const SizedBox(height: 8),
        Text(
          _isDraggingFile
              ? 'Drop image to use it'
              : compact
              ? 'Drop another image to replace this one'
              : 'Drag and drop a meal photo',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        if (!compact) ...[
          const SizedBox(height: 4),
          const Text(
            'Drop, paste, or choose a JPG, PNG, or WebP image.',
            textAlign: TextAlign.center,
          ),
        ],
      ],
    ),
  );

  Widget _stat(String label, String value, IconData icon, Color color) =>
      SizedBox(
        width: 190,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.13),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(color: Color(0xff527060)),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _section({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xffe2f1e5),
                child: Icon(icon, color: const Color(0xff287a54)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: Color(0xff527060))),
          const SizedBox(height: 18),
          child,
        ],
      ),
    ),
  );
}

class _ProfileAndDataScreen extends StatefulWidget {
  const _ProfileAndDataScreen({required this.profile, required this.meals});

  final _PersonProfile profile;
  final List<_WebMeal> meals;

  @override
  State<_ProfileAndDataScreen> createState() => _ProfileAndDataScreenState();
}

class _ProfileAndDataScreenState extends State<_ProfileAndDataScreen> {
  late final TextEditingController _name;
  late final TextEditingController _age;
  late final TextEditingController _height;
  late final TextEditingController _weight;
  late final TextEditingController _dietaryPreferences;
  late final TextEditingController _healthContext;
  late String _sex;
  late String _activityLevel;
  late String _goal;

  static const _sexOptions = [
    '',
    'Female',
    'Male',
    'Intersex',
    'Prefer not to say',
  ];
  static const _activityOptions = [
    '',
    'Mostly sedentary',
    'Lightly active',
    'Moderately active',
    'Very active',
  ];
  static const _goalOptions = [
    '',
    'Maintain weight',
    'Gain weight',
    'Lose weight',
    'Build muscle',
    'Improve general nutrition',
  ];

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _name = TextEditingController(text: profile.name);
    _age = TextEditingController(text: profile.age);
    _height = TextEditingController(text: profile.heightCm);
    _weight = TextEditingController(text: profile.weightKg);
    _dietaryPreferences = TextEditingController(
      text: profile.dietaryPreferences,
    );
    _healthContext = TextEditingController(text: profile.healthContext);
    _sex = _sexOptions.contains(profile.sex) ? profile.sex : '';
    _activityLevel = _activityOptions.contains(profile.activityLevel)
        ? profile.activityLevel
        : '';
    _goal = _goalOptions.contains(profile.goal) ? profile.goal : '';
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _age,
      _height,
      _weight,
      _dietaryPreferences,
      _healthContext,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  _PersonProfile _currentProfile() => _PersonProfile(
    name: _name.text.trim(),
    age: _age.text.trim(),
    sex: _sex,
    heightCm: _height.text.trim(),
    weightKg: _weight.text.trim(),
    activityLevel: _activityLevel,
    goal: _goal,
    dietaryPreferences: _dietaryPreferences.text.trim(),
    healthContext: _healthContext.text.trim(),
  );

  void _exportData() {
    final snapshot = {
      'exportedAt': DateTime.now().toIso8601String(),
      'profile': _currentProfile().toJson(),
      'meals': widget.meals.map((meal) => meal.toJson()).toList(),
    };
    final blob = html.Blob([jsonEncode(snapshot)], 'application/json');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final link = html.AnchorElement(href: url)
      ..download = 'nutritrack-backup.json'
      ..style.display = 'none';
    html.document.body?.append(link);
    link.click();
    link.remove();
    html.Url.revokeObjectUrl(url);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Your diary backup is downloading.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & data'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
              children: [
                Text(
                  'Make your insights personal',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Add only what you are comfortable sharing. This profile is saved in this browser and is used to tailor diary insights, not to diagnose or prescribe.',
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'About you',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _field(_name, 'Name (shown only in this browser)'),
                        _field(_age, 'Age', keyboardType: TextInputType.number),
                        DropdownButtonFormField<String>(
                          initialValue: _sex,
                          decoration: const InputDecoration(labelText: 'Sex'),
                          items: _sexOptions
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(
                                    value.isEmpty ? 'Prefer not to say' : value,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _sex = value ?? ''),
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final stacked = constraints.maxWidth < 480;
                            final heightField = _field(
                              _height,
                              'Height (cm)',
                              keyboardType: TextInputType.number,
                            );
                            final weightField = _field(
                              _weight,
                              'Weight (kg)',
                              keyboardType: TextInputType.number,
                            );
                            if (stacked) {
                              return Column(
                                children: [heightField, weightField],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(child: heightField),
                                const SizedBox(width: 12),
                                Expanded(child: weightField),
                              ],
                            );
                          },
                        ),
                        DropdownButtonFormField<String>(
                          initialValue: _activityLevel,
                          decoration: const InputDecoration(
                            labelText: 'Usual activity level',
                          ),
                          items: _activityOptions
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(
                                    value.isEmpty ? 'Not specified' : value,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _activityLevel = value ?? ''),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _goal,
                          decoration: const InputDecoration(labelText: 'Goal'),
                          items: _goalOptions
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(
                                    value.isEmpty ? 'Not specified' : value,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _goal = value ?? ''),
                        ),
                        const SizedBox(height: 12),
                        _field(
                          _dietaryPreferences,
                          'Dietary preferences or restrictions',
                          maxLines: 3,
                        ),
                        _field(
                          _healthContext,
                          'Health context you want considered (optional)',
                          maxLines: 3,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Avoid entering anything you would not want sent to your chosen AI provider when you request insights.',
                          style: TextStyle(
                            color: Color(0xff527060),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: () =>
                              Navigator.pop(context, _currentProfile()),
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Save profile'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your saved data',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${widget.meals.length} diary ${widget.meals.length == 1 ? 'entry' : 'entries'} are saved automatically in this browser.',
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Download a backup before clearing browser data or switching devices. Your AI API key is session-only and is never included in the backup.',
                          style: TextStyle(color: Color(0xff527060)),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _exportData,
                          icon: const Icon(Icons.download_rounded),
                          label: const Text('Download diary backup'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    ),
  );
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
