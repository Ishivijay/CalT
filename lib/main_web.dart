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
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff236b45)),
          useMaterial3: true,
        ),
        home: const NutritionWebHome(),
      );
}

class _WebMeal {
  const _WebMeal({required this.name, required this.kcal, required this.protein, required this.carbs, required this.fat, required this.grams, required this.createdAt});
  final String name;
  final double kcal, protein, carbs, fat, grams;
  final DateTime createdAt;
  Map<String, dynamic> toJson() => {'name': name, 'kcal': kcal, 'protein': protein, 'carbs': carbs, 'fat': fat, 'grams': grams, 'createdAt': createdAt.toIso8601String()};
  factory _WebMeal.fromJson(Map<String, dynamic> json) => _WebMeal(
    name: json['name']?.toString() ?? 'Meal', kcal: _number(json['kcal']), protein: _number(json['protein']), carbs: _number(json['carbs']), fat: _number(json['fat']), grams: _number(json['grams']), createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
  );
}

class _AiItem {
  const _AiItem({required this.name, required this.grams, required this.kcal, required this.protein, required this.carbs, required this.fat});
  final String name;
  final double grams, kcal, protein, carbs, fat;
  _AiItem copyWith({String? name, double? grams, double? kcal, double? protein, double? carbs, double? fat}) => _AiItem(name: name ?? this.name, grams: grams ?? this.grams, kcal: kcal ?? this.kcal, protein: protein ?? this.protein, carbs: carbs ?? this.carbs, fat: fat ?? this.fat);
}

double _number(dynamic value) => value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '') ?? 0;

class NutritionWebHome extends StatefulWidget {
  const NutritionWebHome({super.key});
  @override
  State<NutritionWebHome> createState() => _NutritionWebHomeState();
}

class _NutritionWebHomeState extends State<NutritionWebHome> {
  static const _mealKey = 'ont_web_meals_v1';
  static const _configKey = 'ont_web_ai_config_v1';
  final _factory = LlmProviderFactory(http.Client());
  List<_WebMeal> _meals = [];
  AiProviderConfig _config = AiProviderConfig.empty;
  Uint8List? _image;
  List<_AiItem> _photoItems = [];
  bool _working = false;
  String? _insight;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    try {
      final storedMeals = html.window.localStorage[_mealKey];
      final storedConfig = html.window.sessionStorage[_configKey];
      _meals = storedMeals == null ? [] : (jsonDecode(storedMeals) as List).whereType<Map>().map((item) => _WebMeal.fromJson(Map<String, dynamic>.from(item))).toList();
      _config = storedConfig == null ? AiProviderConfig.empty : AiProviderConfig.fromJson(Map<String, dynamic>.from(jsonDecode(storedConfig) as Map));
    } catch (_) {
      _meals = [];
      _config = AiProviderConfig.empty;
    }
  }

  void _saveMeals() => html.window.localStorage[_mealKey] = jsonEncode(_meals.map((meal) => meal.toJson()).toList());
  void _saveConfig() => html.window.sessionStorage[_configKey] = jsonEncode(_config.toJson());

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
      final reader = html.FileReader()..readAsArrayBuffer(file);
      await reader.onLoadEnd.first;
      if (reader.result is! ByteBuffer || !mounted) {
        _show('Could not read that image. Try a JPG or PNG file.');
        return;
      }
      setState(() {
        _image = Uint8List.view(reader.result as ByteBuffer);
        _photoItems = [];
      });
      _show('Photo selected. Click Analyze to estimate nutrition.');
    } catch (_) {
      _show('Could not open or read the photo. Try a JPG or PNG file.');
    } finally {
      input.remove();
    }
  }

  Future<void> _analyzePhoto() async {
    if (_image == null) return;
    if (!_config.isConfigured) { _show('Configure an AI provider first.'); return; }
    setState(() => _working = true);
    try {
      final response = await _factory.create(_config).sendVisionPrompt(imageBytes: _image!, promptText: '''Analyze this meal image. Return only JSON: {"items":[{"name":"string","estimated_grams":0,"kcal":0,"protein_g":0,"carbs_g":0,"fat_g":0}]}. Estimates may be uncertain; do not give medical advice.''');
      final rawItems = response.json?['items'];
      if (rawItems is! List) throw const LlmException('The AI response did not contain meal items.');
      final items = rawItems.whereType<Map>().map((raw) => Map<String, dynamic>.from(raw)).map((json) => _AiItem(name: json['name']?.toString() ?? '', grams: _number(json['estimated_grams']), kcal: _number(json['kcal']), protein: _number(json['protein_g']), carbs: _number(json['carbs_g']), fat: _number(json['fat_g']))).where((item) => item.name.trim().isNotEmpty).toList();
      if (items.isEmpty) throw const LlmException('No foods were identified. Try another photo.');
      if (mounted) setState(() => _photoItems = items);
    } on LlmException catch (error) { _show(error.message); }
    catch (_) { _show('Could not analyze the photo. Check your provider configuration and try again.'); }
    finally { if (mounted) setState(() => _working = false); }
  }

  void _savePhotoItems() {
    setState(() {
      _meals = [..._meals, ..._photoItems.map((item) => _WebMeal(name: item.name, kcal: item.kcal, protein: item.protein, carbs: item.carbs, fat: item.fat, grams: item.grams, createdAt: DateTime.now()))];
      _photoItems = [];
      _image = null;
      _saveMeals();
    });
    _show('Reviewed photo estimates saved to your diary.');
  }

  Future<void> _generateInsights() async {
    if (!_config.isConfigured) { _show('Configure an AI provider first.'); return; }
    setState(() => _working = true);
    final since = DateTime.now().subtract(const Duration(days: 7));
    final recent = _meals.where((meal) => meal.createdAt.isAfter(since)).toList();
    final kcal = recent.fold<double>(0, (sum, meal) => sum + meal.kcal);
    final protein = recent.fold<double>(0, (sum, meal) => sum + meal.protein);
    final carbs = recent.fold<double>(0, (sum, meal) => sum + meal.carbs);
    final fat = recent.fold<double>(0, (sum, meal) => sum + meal.fat);
    try {
      final result = await _factory.create(_config).sendTextPrompt('Write a short, non-judgmental nutrition diary summary with 2 practical suggestions and one positive observation. Use only these 7-day aggregates: ${recent.length} entries, ${kcal.toStringAsFixed(0)} kcal, ${protein.toStringAsFixed(0)}g protein, ${carbs.toStringAsFixed(0)}g carbs, ${fat.toStringAsFixed(0)}g fat. This is not medical advice.');
      if (mounted) setState(() => _insight = result.rawText);
    } on LlmException catch (error) { _show(error.message); }
    catch (_) { _show('Could not generate insights.'); }
    finally { if (mounted) setState(() => _working = false); }
  }

  void _show(String text) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text))); }

  Future<void> _editPhotoItem(int index) async {
    final item = _photoItems[index];
    final name = TextEditingController(text: item.name); final grams = TextEditingController(text: item.grams.toStringAsFixed(0)); final kcal = TextEditingController(text: item.kcal.toStringAsFixed(0)); final protein = TextEditingController(text: item.protein.toStringAsFixed(1)); final carbs = TextEditingController(text: item.carbs.toStringAsFixed(1)); final fat = TextEditingController(text: item.fat.toStringAsFixed(1));
    final edited = await showDialog<_AiItem>(context: context, builder: (context) => AlertDialog(title: const Text('Review AI estimate'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [_input(name, 'Food name'), _input(grams, 'Grams'), _input(kcal, 'Calories'), _input(protein, 'Protein (g)'), _input(carbs, 'Carbs (g)'), _input(fat, 'Fat (g)')])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, item.copyWith(name: name.text, grams: _number(grams.text), kcal: _number(kcal.text), protein: _number(protein.text), carbs: _number(carbs.text), fat: _number(fat.text))), child: const Text('Apply'))]));
    for (final controller in [name, grams, kcal, protein, carbs, fat]) { controller.dispose(); }
    if (edited != null && mounted) setState(() => _photoItems = [..._photoItems]..[index] = edited);
  }

  Widget _input(TextEditingController controller, String label) => Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(controller: controller, keyboardType: label == 'Food name' ? TextInputType.text : const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: label, border: const OutlineInputBorder())));

  Future<void> _addManualMeal() async {
    final name = TextEditingController(); final kcal = TextEditingController(); final protein = TextEditingController(); final carbs = TextEditingController(); final fat = TextEditingController();
    final meal = await showDialog<_WebMeal>(context: context, builder: (context) => AlertDialog(title: const Text('Add meal'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [_input(name, 'Food name'), _input(kcal, 'Calories'), _input(protein, 'Protein (g)'), _input(carbs, 'Carbs (g)'), _input(fat, 'Fat (g)')])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, _WebMeal(name: name.text.trim(), kcal: _number(kcal.text), protein: _number(protein.text), carbs: _number(carbs.text), fat: _number(fat.text), grams: 100, createdAt: DateTime.now())), child: const Text('Save'))]));
    for (final controller in [name, kcal, protein, carbs, fat]) { controller.dispose(); }
    if (meal != null && meal.name.isNotEmpty) setState(() { _meals = [..._meals, meal]; _saveMeals(); });
  }

  Future<void> _settings() async {
    var provider = _config.provider; final model = TextEditingController(text: _config.modelId); final key = TextEditingController(text: _config.apiKey); final base = TextEditingController(text: _config.baseUrl ?? '');
    final config = await showDialog<AiProviderConfig>(context: context, builder: (context) => StatefulBuilder(builder: (context, update) => AlertDialog(title: const Text('AI provider (BYOK)'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('Your API key is held only for this browser session. Photos and prompts are sent to the provider you choose.'), const SizedBox(height: 16), DropdownButtonFormField<AiProviderKind>(value: provider, items: const [DropdownMenuItem(value: AiProviderKind.openAi, child: Text('OpenAI')), DropdownMenuItem(value: AiProviderKind.anthropic, child: Text('Anthropic')), DropdownMenuItem(value: AiProviderKind.gemini, child: Text('Gemini')), DropdownMenuItem(value: AiProviderKind.customOpenAi, child: Text('Custom OpenAI-compatible'))], onChanged: (value) => update(() => provider = value!)), const SizedBox(height: 12), _input(model, 'Model ID'), if (provider == AiProviderKind.customOpenAi) _input(base, 'Base URL'), _input(key, 'API key')])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, AiProviderConfig(provider: provider, apiKey: key.text, modelId: model.text, baseUrl: base.text)), child: const Text('Save'))])));
    model.dispose(); key.dispose(); base.dispose();
    if (config != null) setState(() { _config = config; _saveConfig(); });
  }

  @override
  Widget build(BuildContext context) {
    final today = _meals.where((meal) => DateUtils.isSameDay(meal.createdAt, DateTime.now())).toList();
    final kcal = today.fold<double>(0, (sum, meal) => sum + meal.kcal);
    final protein = today.fold<double>(0, (sum, meal) => sum + meal.protein);
    final carbs = today.fold<double>(0, (sum, meal) => sum + meal.carbs);
    final fat = today.fold<double>(0, (sum, meal) => sum + meal.fat);
    return Scaffold(appBar: AppBar(title: const Text('OpenNutriTracker Web'), actions: [IconButton(onPressed: _settings, icon: const Icon(Icons.settings_outlined), tooltip: 'AI settings')]), floatingActionButton: FloatingActionButton.extended(onPressed: _addManualMeal, icon: const Icon(Icons.add), label: const Text('Add meal')), body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 980), child: ListView(padding: const EdgeInsets.all(20), children: [Text('Today', style: Theme.of(context).textTheme.headlineMedium), const SizedBox(height: 12), Wrap(spacing: 12, runSpacing: 12, children: [_stat('Calories', '${kcal.toStringAsFixed(0)} kcal'), _stat('Protein', '${protein.toStringAsFixed(0)} g'), _stat('Carbs', '${carbs.toStringAsFixed(0)} g'), _stat('Fat', '${fat.toStringAsFixed(0)} g')]), const SizedBox(height: 24), _section('Log with photo', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [if (_image != null) ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(_image!, height: 220, width: double.infinity, fit: BoxFit.cover)), Row(children: [OutlinedButton.icon(onPressed: _working ? null : _selectPhoto, icon: const Icon(Icons.upload_file), label: const Text('Choose photo')), const SizedBox(width: 12), FilledButton.icon(onPressed: _image == null || _working ? null : _analyzePhoto, icon: _working ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome), label: const Text('Analyze'))]), if (_photoItems.isNotEmpty) ...[const SizedBox(height: 12), const Text('Review estimates before saving'), for (var i = 0; i < _photoItems.length; i++) ListTile(onTap: () => _editPhotoItem(i), title: Text(_photoItems[i].name), subtitle: Text('${_photoItems[i].grams.toStringAsFixed(0)}g · ${_photoItems[i].kcal.toStringAsFixed(0)} kcal'), trailing: IconButton(onPressed: () => setState(() => _photoItems = [..._photoItems]..removeAt(i)), icon: const Icon(Icons.delete_outline))), FilledButton(onPressed: _savePhotoItems, child: const Text('Confirm and save'))]])), const SizedBox(height: 16), _section('AI insights', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('AI-generated, not medical advice.'), const SizedBox(height: 8), FilledButton.icon(onPressed: _working ? null : _generateInsights, icon: const Icon(Icons.insights_outlined), label: const Text('Generate insights')), if (_insight != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_insight!))])), const SizedBox(height: 16), Text('Diary', style: Theme.of(context).textTheme.titleLarge), if (today.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text('No meals logged today. Add one manually or use a photo.')), for (final meal in today.reversed) Card(child: ListTile(title: Text(meal.name), subtitle: Text('${meal.grams.toStringAsFixed(0)} g · P ${meal.protein.toStringAsFixed(1)}g · C ${meal.carbs.toStringAsFixed(1)}g · F ${meal.fat.toStringAsFixed(1)}g'), trailing: Text('${meal.kcal.toStringAsFixed(0)} kcal'))), const SizedBox(height: 90)]))));
  }

  Widget _stat(String label, String value) => SizedBox(width: 180, child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label), const SizedBox(height: 4), Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))]))));
  Widget _section(String title, Widget child) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)), const SizedBox(height: 12), child])));
}

extension<T> on List<T> { T? get firstOrNull => isEmpty ? null : first; }
