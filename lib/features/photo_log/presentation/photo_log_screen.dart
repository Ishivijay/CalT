import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/presentation/widgets/voice_input_button.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/ai_provider/data/ai_provider_config_store.dart';
import 'package:opennutritracker/features/ai_provider/domain/llm_provider.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_bloc.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/features/photo_log/data/photo_food_matcher.dart';
import 'package:opennutritracker/features/photo_log/data/photo_meal_analyzer.dart';
import 'package:opennutritracker/features/photo_log/domain/ai_photo_meal_item.dart';
import 'package:opennutritracker/features/photo_log/domain/save_ai_photo_meals_usecase.dart';

class PhotoLogScreenArguments {
  const PhotoLogScreenArguments({required this.day});
  final DateTime day;
}

class PhotoLogScreen extends StatefulWidget {
  const PhotoLogScreen({super.key});
  @override
  State<PhotoLogScreen> createState() => _PhotoLogScreenState();
}

class _PhotoLogScreenState extends State<PhotoLogScreen> {
  final _hint = TextEditingController();
  final _picker = ImagePicker();
  Uint8List? _image;
  List<AiPhotoMealItem> _items = const [];
  String? _notes;
  bool _working = false;
  bool _saving = false;
  IntakeTypeEntity _type = IntakeTypeEntity.dinner;

  @override
  void dispose() {
    _hint.dispose();
    super.dispose();
  }

  DateTime get _day =>
      (ModalRoute.of(context)?.settings.arguments as PhotoLogScreenArguments?)
          ?.day ??
      DateTime.now();

  Future<void> _pick(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      imageQuality: 88,
      maxWidth: 2000,
    );
    if (file == null) {
      return;
    }
    final original = await file.readAsBytes();
    final compressed = await FlutterImageCompress.compressWithList(
      original,
      minWidth: 1600,
      minHeight: 1600,
      quality: 82,
      format: CompressFormat.jpeg,
    );
    if (mounted) {
      setState(() {
        _image = compressed;
        _items = const [];
        _notes = null;
      });
    }
  }

  Future<void> _analyze() async {
    if (_image == null) return;
    final config = await locator<AiProviderConfigStore>().read();
    if (!config.isConfigured) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Set up an AI provider before analyzing a photo.'),
        ),
      );
      await Navigator.of(
        context,
      ).pushNamed(NavigationOptions.aiProviderSettingsRoute);
      return;
    }
    setState(() => _working = true);
    try {
      final analysis = await locator<PhotoMealAnalyzer>().analyze(
        _image!,
        hint: _hint.text,
      );
      final matched = await Future.wait(
        analysis.items.map(locator<PhotoFoodMatcher>().verify),
      );
      if (mounted) {
        setState(() {
          _items = matched;
          _notes = analysis.notes;
        });
      }
    } on LlmException catch (error) {
      _message(error.message);
    } catch (_) {
      _message('Could not analyze this photo. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _edit(int index) async {
    final item = _items[index];
    final name = TextEditingController(text: item.name);
    final grams = TextEditingController(text: item.grams.toStringAsFixed(0));
    final kcal = TextEditingController(text: item.kcal.toStringAsFixed(0));
    final protein = TextEditingController(
      text: item.proteinG.toStringAsFixed(1),
    );
    final carbs = TextEditingController(text: item.carbsG.toStringAsFixed(1));
    final fat = TextEditingController(text: item.fatG.toStringAsFixed(1));
    final changed = await showDialog<AiPhotoMealItem>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit estimate'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(name, 'Food name'),
              _field(grams, 'Grams'),
              _field(kcal, 'Calories (kcal)'),
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
              item.copyWith(
                name: name.text.trim(),
                grams: _number(grams.text),
                kcal: _number(kcal.text),
                proteinG: _number(protein.text),
                carbsG: _number(carbs.text),
                fatG: _number(fat.text),
                clearReferenceMeal: true,
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
    if (changed != null && mounted) {
      setState(() => _items = [..._items]..[index] = changed);
    }
  }

  Widget _field(TextEditingController controller, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: label == 'Food name'
            ? VoiceInputButton(controller: controller)
            : null,
      ),
      keyboardType: label == 'Food name'
          ? TextInputType.text
          : const TextInputType.numberWithOptions(decimal: true),
    ),
  );
  double _number(String text) =>
      double.tryParse(text.replaceAll(',', '.')) ?? 0;

  Future<void> _save() async {
    if (_items.isEmpty) return;
    setState(() => _saving = true);
    try {
      await locator<SaveAiPhotoMealsUsecase>().save(_items, _type, _day);
      locator<HomeBloc>().add(const LoadItemsEvent());
      locator<DiaryBloc>().add(const LoadDiaryYearEvent());
      locator<CalendarDayBloc>().add(RefreshCalendarDayEvent());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI meal estimate saved to your diary.')),
      );
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(NavigationOptions.mainRoute, (route) => false);
    } catch (_) {
      _message('Could not save the meal. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Log with photo')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_image == null)
          Container(
            height: 210,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.add_a_photo_outlined, size: 64),
          )
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.memory(_image!, height: 230, fit: BoxFit.cover),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _working ? null : () => _pick(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Camera'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _working ? null : () => _pick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Gallery'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _hint,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: 'Optional meal hint',
            hintText: 'e.g. pan-fried in olive oil, large portion',
            border: const OutlineInputBorder(),
            suffixIcon: VoiceInputButton(controller: _hint),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _image == null || _working ? null : _analyze,
          icon: _working
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome),
          label: Text(_working ? 'Estimating…' : 'Estimate nutrition'),
        ),
        if (_items.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Review before saving',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          const Text(
            'AI estimates can be wrong. Edit or remove every item you want to change.',
          ),
          if (_notes?.isNotEmpty ?? false)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _notes!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 12),
          for (var i = 0; i < _items.length; i++) _reviewCard(i),
          DropdownButtonFormField<IntakeTypeEntity>(
            initialValue: _type,
            decoration: const InputDecoration(
              labelText: 'Meal type',
              border: OutlineInputBorder(),
            ),
            items: IntakeTypeEntity.values
                .map(
                  (type) => DropdownMenuItem(
                    value: type,
                    child: Text(
                      type.name[0].toUpperCase() + type.name.substring(1),
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _type = value!),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: const Text('Confirm and save'),
          ),
        ],
      ],
    ),
  );

  Widget _reviewCard(int index) {
    final item = _items[index];
    return Card(
      child: ListTile(
        onTap: () => _edit(index),
        title: Text(item.name),
        subtitle: Text(
          '${item.grams.toStringAsFixed(0)} g · ${item.kcal.toStringAsFixed(0)} kcal\nP ${item.proteinG.toStringAsFixed(1)}g · C ${item.carbsG.toStringAsFixed(1)}g · F ${item.fatG.toStringAsFixed(1)}g',
        ),
        isThreeLine: true,
        leading: Icon(
          item.verified ? Icons.verified_rounded : Icons.auto_awesome_outlined,
          color: item.verified ? Colors.green : null,
        ),
        trailing: IconButton(
          tooltip: 'Remove',
          icon: const Icon(Icons.delete_outline),
          onPressed: () =>
              setState(() => _items = [..._items]..removeAt(index)),
        ),
      ),
    );
  }
}
