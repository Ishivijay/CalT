import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:opennutritracker/features/ai_provider/data/http_llm_providers.dart';
import 'package:opennutritracker/features/ai_provider/domain/ai_provider_config.dart';
import 'package:opennutritracker/features/ai_provider/domain/llm_provider.dart';
import 'package:table_calendar/table_calendar.dart';

void main() => runApp(const NutritionWebApp());

class NutritionWebApp extends StatelessWidget {
  const NutritionWebApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'OpenNutriTracker Web',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff1d5d50),
        brightness: Brightness.light,
        surface: const Color(0xfffcfdfa),
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xfff1f5f2),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xffdce8df)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xff1d5d50),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
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
    this.targetKcal = '',
    this.targetProtein = '',
    this.targetCarbs = '',
    this.targetFat = '',
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
  final String targetKcal;
  final String targetProtein;
  final String targetCarbs;
  final String targetFat;
  final String dietaryPreferences;
  final String healthContext;

  bool get hasDetails => [
    age,
    sex,
    heightCm,
    weightKg,
    activityLevel,
    goal,
    targetKcal,
    targetProtein,
    targetCarbs,
    targetFat,
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
    'targetKcal': targetKcal,
    'targetProtein': targetProtein,
    'targetCarbs': targetCarbs,
    'targetFat': targetFat,
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
    targetKcal: json['targetKcal']?.toString() ?? '',
    targetProtein: json['targetProtein']?.toString() ?? '',
    targetCarbs: json['targetCarbs']?.toString() ?? '',
    targetFat: json['targetFat']?.toString() ?? '',
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
  String? _weeklyCoach;
  final List<void Function()> _webEventCleanups = [];
  final _photoFuelKey = GlobalKey();
  final _coachKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _load();
    _listenForImageDrops();
  }

  @override
  void dispose() {
    for (final cleanup in _webEventCleanups) {
      cleanup();
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

  void _scrollTo(GlobalKey key) {
    final target = key.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  void _listenForImageDrops() {
    void listen(String type, void Function(html.Event) handler) {
      html.document.addEventListener(type, handler, true);
      _webEventCleanups.add(
        () => html.document.removeEventListener(type, handler, true),
      );
    }

    // Flutter renders inside a browser canvas. Capture these events before the
    // canvas can consume them or the browser navigates to the dropped file.
    listen('dragover', _handleGlobalDragOver);
    listen('dragleave', _handleGlobalDragLeave);
    listen('drop', _handleGlobalDrop);
    listen('paste', _handleGlobalPaste);
  }

  void _handleGlobalDragOver(html.Event event) {
    event.preventDefault();
    if (mounted && !_isDraggingFile) setState(() => _isDraggingFile = true);
  }

  void _handleGlobalDragLeave(html.Event event) {
    if (mounted) setState(() => _isDraggingFile = false);
  }

  void _handleGlobalDrop(html.Event event) {
    event.preventDefault();
    if (mounted) setState(() => _isDraggingFile = false);
    if (event is! html.MouseEvent) return;
    final file = event.dataTransfer.files?.firstOrNull;
    if (file != null) unawaited(_loadImageFile(file));
  }

  void _handleGlobalPaste(html.Event event) {
    if (event is! html.ClipboardEvent) return;
    final file = event.clipboardData?.files?.firstOrNull;
    if (file != null) unawaited(_loadImageFile(file));
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

  Future<void> _scanBarcode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => const _BarcodeScannerScreen()),
    );
    if (code == null || code.trim().isEmpty || !mounted) return;
    await _lookupBarcode(code.trim());
  }

  Future<void> _lookupBarcode(String code) async {
    _show('Looking up barcode $code…');
    try {
      final response = await http.get(
        Uri.parse(
          'https://world.openfoodfacts.org/api/v2/product/$code.json?fields=product_name,product_name_en,serving_quantity,nutriments',
        ),
      );
      final payload = jsonDecode(response.body);
      if (response.statusCode != 200 ||
          payload is! Map ||
          payload['status'] != 1) {
        throw const FormatException();
      }
      final product = Map<String, dynamic>.from(payload['product'] as Map);
      final nutriments = product['nutriments'] is Map
          ? Map<String, dynamic>.from(product['nutriments'] as Map)
          : <String, dynamic>{};
      final name = (product['product_name'] ?? product['product_name_en'] ?? '')
          .toString()
          .trim();
      if (name.isEmpty) throw const FormatException();
      await _reviewBarcodeProduct(
        name: name,
        grams: _number(product['serving_quantity']) > 0
            ? _number(product['serving_quantity'])
            : 100,
        kcalPer100: _number(nutriments['energy-kcal_100g']),
        proteinPer100: _number(nutriments['proteins_100g']),
        carbsPer100: _number(nutriments['carbohydrates_100g']),
        fatPer100: _number(nutriments['fat_100g']),
      );
    } catch (_) {
      _show('Food not found. Try another barcode or add the meal manually.');
    }
  }

  Future<void> _reviewBarcodeProduct({
    required String name,
    required double grams,
    required double kcalPer100,
    required double proteinPer100,
    required double carbsPer100,
    required double fatPer100,
  }) async {
    final amount = TextEditingController(text: grams.toStringAsFixed(0));
    final meal = await showDialog<_WebMeal>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Barcode match'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text(
              'Nutrition values come from Open Food Facts. Check the serving before saving.',
            ),
            const SizedBox(height: 16),
            _input(amount, 'Serving amount (g)'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final factor = _number(amount.text) / 100;
              Navigator.pop(
                context,
                _WebMeal(
                  name: name,
                  grams: _number(amount.text),
                  kcal: kcalPer100 * factor,
                  protein: proteinPer100 * factor,
                  carbs: carbsPer100 * factor,
                  fat: fatPer100 * factor,
                  createdAt: DateTime.now(),
                ),
              );
            },
            child: const Text('Add to diary'),
          ),
        ],
      ),
    );
    amount.dispose();
    if (meal == null || !mounted) return;
    setState(() {
      _meals = [..._meals, meal];
      _saveMeals();
    });
    _show('$name added to your diary.');
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

  Future<void> _generateWeeklyCoach() async {
    if (!_config.isConfigured) {
      _show('Configure an AI provider first.');
      return;
    }
    final end = DateTime.now();
    final start = DateTime(
      end.year,
      end.month,
      end.day,
    ).subtract(const Duration(days: 6));
    final weekMeals = _meals
        .where((meal) => !meal.createdAt.isBefore(start))
        .toList();
    if (weekMeals.isEmpty) {
      _show('Log at least one meal this week before asking your coach.');
      return;
    }
    final days = <String, List<_WebMeal>>{};
    for (final meal in weekMeals) {
      final key = meal.createdAt.toIso8601String().substring(0, 10);
      (days[key] ??= []).add(meal);
    }
    final dayLines = days.entries
        .map((entry) {
          final meals = entry.value;
          final kcal = meals.fold<double>(0, (sum, meal) => sum + meal.kcal);
          final protein = meals.fold<double>(
            0,
            (sum, meal) => sum + meal.protein,
          );
          return '${entry.key}: ${meals.length} meals, ${kcal.toStringAsFixed(0)} kcal, ${protein.toStringAsFixed(0)}g protein. Foods: ${meals.map((meal) => meal.name).join(', ')}';
        })
        .join('\n');
    setState(() => _working = true);
    try {
      final result = await _factory.create(_config).sendTextPrompt(
        '''You are a supportive fitness nutrition coach. Review this person's last seven calendar days of logged meals. Base every observation on the diary, not generic advice. ${_profile.promptContext}

Give concise plain text sections only (no Markdown):
WEEKLY CONSISTENCY:
PROTEIN DISTRIBUTION:
FUEL AND RECOVERY:
NEXT WEEK FOCUS:
DATA LIMIT:

Do not diagnose, prescribe, estimate unlogged nutrients, or assume workouts occurred. If few days are logged, say so clearly and tailor the feedback to the logged days.

WEEKLY DIARY:
$dayLines''',
      );
      if (mounted) setState(() => _weeklyCoach = _cleanInsight(result.rawText));
    } on LlmException catch (error) {
      _show(error.message);
    } catch (_) {
      _show('Could not generate the weekly coach summary.');
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

  Future<void> _viewDiaryMeal(_WebMeal meal) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(meal.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${meal.grams.toStringAsFixed(0)} g serving'),
            const SizedBox(height: 14),
            Text(
              '${meal.kcal.toStringAsFixed(0)} kcal',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Text('Protein  ${meal.protein.toStringAsFixed(1)} g'),
            Text('Carbs  ${meal.carbs.toStringAsFixed(1)} g'),
            Text('Fat  ${meal.fat.toStringAsFixed(1)} g'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _editDiaryMeal(meal);
            },
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  Future<void> _editDiaryMeal(_WebMeal original) async {
    final name = TextEditingController(text: original.name);
    final grams = TextEditingController(
      text: original.grams.toStringAsFixed(0),
    );
    final kcal = TextEditingController(text: original.kcal.toStringAsFixed(0));
    final protein = TextEditingController(
      text: original.protein.toStringAsFixed(1),
    );
    final carbs = TextEditingController(
      text: original.carbs.toStringAsFixed(1),
    );
    final fat = TextEditingController(text: original.fat.toStringAsFixed(1));
    final edited = await showDialog<_WebMeal>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit diary entry'),
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
              _WebMeal(
                name: name.text.trim(),
                grams: _number(grams.text),
                kcal: _number(kcal.text),
                protein: _number(protein.text),
                carbs: _number(carbs.text),
                fat: _number(fat.text),
                createdAt: original.createdAt,
              ),
            ),
            child: const Text('Save changes'),
          ),
        ],
      ),
    );
    for (final controller in [name, grams, kcal, protein, carbs, fat]) {
      controller.dispose();
    }
    if (edited == null || edited.name.isEmpty || !mounted) return;
    final index = _meals.indexOf(original);
    if (index == -1) return;
    setState(() {
      _meals = [..._meals]..[index] = edited;
      _saveMeals();
    });
    _show('Diary entry updated.');
  }

  Future<void> _deleteDiaryMeal(_WebMeal meal) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete entry?'),
        content: Text('Remove ${meal.name} from today\'s diary?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (remove != true || !mounted) return;
    setState(() {
      _meals = [..._meals]..remove(meal);
      _saveMeals();
    });
    _show('Diary entry deleted.');
  }

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

  Future<void> _openDiaryCalendar() async {
    final meals = await Navigator.of(context).push<List<_WebMeal>>(
      MaterialPageRoute(
        builder: (context) => _DiaryCalendarScreen(meals: _meals),
      ),
    );
    if (meals == null || !mounted) return;
    setState(() {
      _meals = meals;
      _saveMeals();
    });
    _show('Diary changes saved.');
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
            Icon(Icons.bolt_rounded, color: Color(0xff1d5d50)),
            SizedBox(width: 8),
            Text('NUTRITRACK'),
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wideLayout = constraints.maxWidth >= 1100;
            return Row(
              children: [
                if (wideLayout) _fitnessSidebar(),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: wideLayout ? 1480 : 1040,
                      ),
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                          wideLayout ? 34 : 20,
                          wideLayout ? 26 : 12,
                          wideLayout ? 34 : 20,
                          110,
                        ),
                        children: [
                          Text(
                            greetingWithName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: const Color(0xff527060),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Fuel the work.\nOwn the day.',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 0.98,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xff163e36), Color(0xff287a62)],
                              ),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Row(
                              children: [
                                const CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Color(0xffb9ff64),
                                  child: Icon(
                                    Icons.bolt_rounded,
                                    color: Color(0xff163e36),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'TODAY\'S FUEL',
                                        style: theme.textTheme.titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                              letterSpacing: 0.5,
                                            ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        today.isEmpty
                                            ? 'Start with a meal, a photo, or a quick note.'
                                            : '${today.length} ${today.length == 1 ? 'entry' : 'entries'} logged today.',
                                        style: const TextStyle(
                                          color: Color(0xffd6eee1),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        kcal.toStringAsFixed(0),
                                        style: const TextStyle(
                                          color: Color(0xffb9ff64),
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const Text(
                                        'KCAL',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.8,
                                        ),
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
                          const SizedBox(height: 16),
                          _targetRings(kcal, protein, carbs, fat),
                          const SizedBox(height: 28),
                          KeyedSubtree(
                            key: _photoFuelKey,
                            child: _section(
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
                                        onPressed: _working
                                            ? null
                                            : _selectPhoto,
                                        icon: const Icon(
                                          Icons.photo_library_outlined,
                                        ),
                                        label: Text(
                                          _image == null
                                              ? 'Choose photo'
                                              : 'Replace photo',
                                        ),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: _working
                                            ? null
                                            : _scanBarcode,
                                        icon: const Icon(
                                          Icons.qr_code_scanner_rounded,
                                        ),
                                        label: const Text('Scan barcode'),
                                      ),
                                      FilledButton.icon(
                                        onPressed: _image == null || _working
                                            ? null
                                            : _analyzePhoto,
                                        icon: _working
                                            ? const SizedBox.square(
                                                dimension: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                              )
                                            : const Icon(
                                                Icons.auto_awesome_rounded,
                                              ),
                                        label: Text(
                                          _working
                                              ? 'Analyzing…'
                                              : 'Analyze meal',
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_photoItems.isNotEmpty) ...[
                                    const SizedBox(height: 20),
                                    Text(
                                      'Review estimates',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
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
                                        margin: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xfff4f8f3),
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        child: ListTile(
                                          onTap: () => _editPhotoItem(i),
                                          leading: const CircleAvatar(
                                            child: Icon(
                                              Icons.restaurant_rounded,
                                            ),
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
                                            icon: const Icon(
                                              Icons.delete_outline_rounded,
                                            ),
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
                                  onPressed: _working
                                      ? null
                                      : _generateInsights,
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
                          const SizedBox(height: 16),
                          KeyedSubtree(
                            key: _coachKey,
                            child: _section(
                              title: 'Weekly AI coach',
                              subtitle:
                                  'Consistency, protein distribution, and practical fuelling or recovery suggestions from your last 7 days.',
                              icon: Icons.psychology_alt_outlined,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  FilledButton.icon(
                                    onPressed: _working
                                        ? null
                                        : _generateWeeklyCoach,
                                    icon: const Icon(
                                      Icons.auto_awesome_rounded,
                                    ),
                                    label: const Text('Review my week'),
                                  ),
                                  if (_weeklyCoach != null) ...[
                                    const SizedBox(height: 14),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xffeef6ee),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Text(
                                        _weeklyCoach!,
                                        style: const TextStyle(height: 1.45),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
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
                              TextButton.icon(
                                onPressed: _openDiaryCalendar,
                                icon: const Icon(Icons.calendar_month_rounded),
                                label: const Text('Calendar'),
                              ),
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
                                border: Border.all(
                                  color: const Color(0xffdfe9df),
                                ),
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
                                onTap: () => _viewDiaryMeal(meal),
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
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(
                                  '${meal.grams.toStringAsFixed(0)} g · P ${meal.protein.toStringAsFixed(1)} g · C ${meal.carbs.toStringAsFixed(1)} g · F ${meal.fat.toStringAsFixed(1)} g',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${meal.kcal.toStringAsFixed(0)}\nkcal',
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      tooltip: 'Entry actions',
                                      onSelected: (action) {
                                        switch (action) {
                                          case 'view':
                                            _viewDiaryMeal(meal);
                                          case 'edit':
                                            _editDiaryMeal(meal);
                                          case 'delete':
                                            _deleteDiaryMeal(meal);
                                        }
                                      },
                                      itemBuilder: (context) => const [
                                        PopupMenuItem(
                                          value: 'view',
                                          child: Text('View details'),
                                        ),
                                        PopupMenuItem(
                                          value: 'edit',
                                          child: Text('Edit entry'),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Text('Delete entry'),
                                        ),
                                      ],
                                    ),
                                  ],
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
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _fitnessSidebar() => Container(
    width: 264,
    margin: const EdgeInsets.fromLTRB(16, 16, 0, 16),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xff102d29), Color(0xff1d5d50), Color(0xff133a35)],
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            CircleAvatar(
              backgroundColor: Color(0xffb9ff64),
              child: Icon(Icons.bolt_rounded, color: Color(0xff163e36)),
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NUTRITRACK',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
                Text(
                  'FUEL YOUR TRAINING',
                  style: TextStyle(
                    color: Color(0xffb7d6c6),
                    fontSize: 10,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 42),
        _sideAction(Icons.grid_view_rounded, 'Dashboard', selected: true),
        _sideAction(
          Icons.camera_alt_outlined,
          'Photo fuel',
          onTap: () => _scrollTo(_photoFuelKey),
        ),
        _sideAction(
          Icons.auto_graph_rounded,
          'AI coach',
          onTap: () => _scrollTo(_coachKey),
        ),
        _sideAction(
          Icons.person_outline_rounded,
          'Profile & data',
          onTap: _openProfileAndData,
        ),
        _sideAction(Icons.tune_rounded, 'AI settings', onTap: _settings),
        const Spacer(),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PERSONAL MODE',
                style: TextStyle(
                  color: Color(0xffb9ff64),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _profile.hasDetails
                    ? 'Profile-powered insights are on.'
                    : 'Add a profile to personalize your AI coach.',
                style: const TextStyle(color: Colors.white, height: 1.3),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _openProfileAndData,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xffb9ff64),
                  padding: EdgeInsets.zero,
                ),
                child: const Text('Set up profile  →'),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _sideAction(
    IconData icon,
    String label, {
    bool selected = false,
    VoidCallback? onTap,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Material(
      color: selected
          ? Colors.white.withValues(alpha: 0.14)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected
                    ? const Color(0xffb9ff64)
                    : const Color(0xffd8ece0),
                size: 21,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

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

  Widget _targetRings(double kcal, double protein, double carbs, double fat) {
    final targets = [
      ('CALORIES', kcal, _number(_profile.targetKcal), const Color(0xffe06d3d)),
      (
        'PROTEIN',
        protein,
        _number(_profile.targetProtein),
        const Color(0xff635fc7),
      ),
      ('CARBS', carbs, _number(_profile.targetCarbs), const Color(0xffd09530)),
      ('FAT', fat, _number(_profile.targetFat), const Color(0xff1d8b70)),
    ];
    final hasTarget = targets.any((target) => target.$3 > 0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.track_changes_rounded,
                  color: Color(0xff1d5d50),
                ),
                const SizedBox(width: 8),
                const Text(
                  'DAILY TARGETS',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _openProfileAndData,
                  child: Text(hasTarget ? 'Edit targets' : 'Set targets'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.spaceAround,
              spacing: 22,
              runSpacing: 18,
              children: [
                for (final target in targets)
                  _targetRing(target.$1, target.$2, target.$3, target.$4),
              ],
            ),
            if (!hasTarget) ...[
              const SizedBox(height: 12),
              const Text(
                'Set personal calorie and macro targets to see your progress here.',
                style: TextStyle(color: Color(0xff527060)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _targetRing(String label, double current, double target, Color color) {
    final progress = target <= 0 ? 0.0 : (current / target).clamp(0.0, 1.0);
    final currentText = current.toStringAsFixed(0);
    return SizedBox(
      width: 126,
      child: Column(
        children: [
          SizedBox(
            width: 90,
            height: 90,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 90,
                  height: 90,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 9,
                    backgroundColor: color.withValues(alpha: 0.13),
                    color: color,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      currentText,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      target <= 0
                          ? 'set goal'
                          : '/ ${target.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xff527060),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 0.7,
            ),
          ),
        ],
      ),
    );
  }

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

class _BarcodeScannerScreen extends StatefulWidget {
  const _BarcodeScannerScreen();

  @override
  State<_BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<_BarcodeScannerScreen> {
  bool _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final code = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .firstWhere(
          (value) => value != null && value.isNotEmpty,
          orElse: () => null,
        );
    if (code == null) return;
    _handled = true;
    Navigator.pop(context, code);
  }

  Future<void> _enterManually() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter barcode'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Barcode number',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Look up'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code != null && code.isNotEmpty && mounted)
      Navigator.pop(context, code);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: const Text('Scan a food barcode'),
      actions: [
        TextButton.icon(
          onPressed: _enterManually,
          icon: const Icon(Icons.keyboard_rounded),
          label: const Text('Enter code'),
          style: TextButton.styleFrom(foregroundColor: Colors.white),
        ),
      ],
    ),
    body: Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(onDetect: _onDetect),
        Center(
          child: Container(
            width: 270,
            height: 170,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xffb9ff64), width: 3),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        const Positioned(
          bottom: 38,
          left: 24,
          right: 24,
          child: Text(
            'Hold the barcode inside the frame. Camera access requires HTTPS or localhost.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    ),
  );
}

class _DiaryCalendarScreen extends StatefulWidget {
  const _DiaryCalendarScreen({required this.meals});

  final List<_WebMeal> meals;

  @override
  State<_DiaryCalendarScreen> createState() => _DiaryCalendarScreenState();
}

class _DiaryCalendarScreenState extends State<_DiaryCalendarScreen> {
  late List<_WebMeal> _meals;
  late DateTime _focusedDay;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    _meals = [...widget.meals];
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
  }

  List<_WebMeal> _eventsFor(DateTime day) =>
      _meals.where((meal) => DateUtils.isSameDay(meal.createdAt, day)).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  Future<void> _editMeal(_WebMeal original) async {
    final name = TextEditingController(text: original.name);
    final grams = TextEditingController(
      text: original.grams.toStringAsFixed(0),
    );
    final kcal = TextEditingController(text: original.kcal.toStringAsFixed(0));
    final protein = TextEditingController(
      text: original.protein.toStringAsFixed(1),
    );
    final carbs = TextEditingController(
      text: original.carbs.toStringAsFixed(1),
    );
    final fat = TextEditingController(text: original.fat.toStringAsFixed(1));
    final edited = await showDialog<_WebMeal>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit diary entry'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(name, 'Food name'),
              _field(grams, 'Grams'),
              _field(kcal, 'Calories'),
              _field(protein, 'Protein (g)'),
              _field(carbs, 'Carbs (g)'),
              _field(fat, 'Fat (g)'),
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
                grams: _number(grams.text),
                kcal: _number(kcal.text),
                protein: _number(protein.text),
                carbs: _number(carbs.text),
                fat: _number(fat.text),
                createdAt: original.createdAt,
              ),
            ),
            child: const Text('Save changes'),
          ),
        ],
      ),
    );
    for (final controller in [name, grams, kcal, protein, carbs, fat]) {
      controller.dispose();
    }
    if (edited == null || edited.name.isEmpty || !mounted) return;
    final index = _meals.indexOf(original);
    setState(() => _meals = [..._meals]..[index] = edited);
  }

  Future<void> _deleteMeal(_WebMeal meal) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete entry?'),
        content: Text('Remove ${meal.name} from your diary?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (remove == true && mounted) setState(() => _meals.remove(meal));
  }

  @override
  Widget build(BuildContext context) {
    final selectedMeals = _eventsFor(_selectedDay);
    final total = selectedMeals.fold<double>(0, (sum, meal) => sum + meal.kcal);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diary calendar'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context, _meals),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 940),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: TableCalendar<_WebMeal>(
                    firstDay: DateTime.now().subtract(
                      const Duration(days: 730),
                    ),
                    lastDay: DateTime.now().add(const Duration(days: 365)),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) =>
                        DateUtils.isSameDay(day, _selectedDay),
                    eventLoader: _eventsFor,
                    startingDayOfWeek: StartingDayOfWeek.monday,
                    calendarStyle: const CalendarStyle(
                      markerDecoration: BoxDecoration(
                        color: Color(0xffb9ff64),
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: Color(0xff1d5d50),
                        shape: BoxShape.circle,
                      ),
                      todayDecoration: BoxDecoration(
                        color: Color(0xff72a896),
                        shape: BoxShape.circle,
                      ),
                    ),
                    onDaySelected: (selected, focused) => setState(() {
                      _selectedDay = selected;
                      _focusedDay = focused;
                    }),
                    onPageChanged: (focused) => _focusedDay = focused,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  const Icon(Icons.today_rounded, color: Color(0xff1d5d50)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_selectedDay.year}-${_selectedDay.month.toString().padLeft(2, '0')}-${_selectedDay.day.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${total.toStringAsFixed(0)} kcal',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (selectedMeals.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No meals logged for this day.',
                    textAlign: TextAlign.center,
                  ),
                ),
              for (final meal in selectedMeals)
                Card(
                  child: ListTile(
                    onTap: () => _editMeal(meal),
                    title: Text(
                      meal.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${meal.grams.toStringAsFixed(0)} g · P ${meal.protein.toStringAsFixed(1)} g · C ${meal.carbs.toStringAsFixed(1)} g · F ${meal.fat.toStringAsFixed(1)} g',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${meal.kcal.toStringAsFixed(0)} kcal'),
                        IconButton(
                          onPressed: () => _deleteMeal(meal),
                          icon: const Icon(Icons.delete_outline_rounded),
                          tooltip: 'Delete entry',
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label) => Padding(
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
  late final TextEditingController _targetKcal;
  late final TextEditingController _targetProtein;
  late final TextEditingController _targetCarbs;
  late final TextEditingController _targetFat;
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
    _targetKcal = TextEditingController(text: profile.targetKcal);
    _targetProtein = TextEditingController(text: profile.targetProtein);
    _targetCarbs = TextEditingController(text: profile.targetCarbs);
    _targetFat = TextEditingController(text: profile.targetFat);
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
      _targetKcal,
      _targetProtein,
      _targetCarbs,
      _targetFat,
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
    targetKcal: _targetKcal.text.trim(),
    targetProtein: _targetProtein.text.trim(),
    targetCarbs: _targetCarbs.text.trim(),
    targetFat: _targetFat.text.trim(),
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
                        const SizedBox(height: 22),
                        Text(
                          'Daily targets',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Optional goals for your dashboard rings. Your AI coach treats these as preferences, not medical prescriptions.',
                        ),
                        const SizedBox(height: 14),
                        LayoutBuilder(
                          builder: (context, constraints) => Wrap(
                            spacing: 12,
                            children: [
                              for (final field in [
                                (_targetKcal, 'Calories (kcal)'),
                                (_targetProtein, 'Protein (g)'),
                                (_targetCarbs, 'Carbs (g)'),
                                (_targetFat, 'Fat (g)'),
                              ])
                                SizedBox(
                                  width: constraints.maxWidth < 520
                                      ? constraints.maxWidth
                                      : (constraints.maxWidth - 12) / 2,
                                  child: _field(
                                    field.$1,
                                    field.$2,
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
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
