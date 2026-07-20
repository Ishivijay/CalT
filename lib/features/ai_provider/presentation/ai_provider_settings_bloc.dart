import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opennutritracker/features/ai_provider/data/ai_provider_config_store.dart';
import 'package:opennutritracker/features/ai_provider/data/http_llm_providers.dart';
import 'package:opennutritracker/features/ai_provider/domain/ai_provider_config.dart';

sealed class AiProviderSettingsEvent extends Equatable {
  const AiProviderSettingsEvent();
  @override
  List<Object?> get props => [];
}
class LoadAiProviderSettings extends AiProviderSettingsEvent { const LoadAiProviderSettings(); }
class SaveAiProviderSettings extends AiProviderSettingsEvent {
  const SaveAiProviderSettings(this.config); final AiProviderConfig config;
}
class TestAiProviderConnection extends AiProviderSettingsEvent {
  const TestAiProviderConnection(this.config); final AiProviderConfig config;
}

sealed class AiProviderSettingsState extends Equatable {
  const AiProviderSettingsState();
  @override
  List<Object?> get props => [];
}
class AiProviderSettingsLoading extends AiProviderSettingsState { const AiProviderSettingsLoading(); }
class AiProviderSettingsReady extends AiProviderSettingsState {
  const AiProviderSettingsReady(this.config, {this.message, this.isTesting = false});
  final AiProviderConfig config; final String? message; final bool isTesting;
  @override
  List<Object?> get props => [config.provider, config.modelId, config.baseUrl, message, isTesting];
}

class AiProviderSettingsBloc extends Bloc<AiProviderSettingsEvent, AiProviderSettingsState> {
  AiProviderSettingsBloc(this._store, this._factory) : super(const AiProviderSettingsLoading()) {
    on<LoadAiProviderSettings>((event, emit) async => emit(AiProviderSettingsReady(await _store.read())));
    on<SaveAiProviderSettings>(_save);
    on<TestAiProviderConnection>(_test);
  }
  final AiProviderConfigStore _store; final LlmProviderFactory _factory;

  Future<void> _save(SaveAiProviderSettings event, Emitter<AiProviderSettingsState> emit) async {
    if (!event.config.isConfigured) {
      emit(AiProviderSettingsReady(event.config, message: 'Enter both a model ID and API key.'));
      return;
    }
    await _store.save(event.config);
    emit(AiProviderSettingsReady(event.config, message: 'AI provider saved securely.'));
  }
  Future<void> _test(TestAiProviderConnection event, Emitter<AiProviderSettingsState> emit) async {
    if (!event.config.isConfigured) {
      emit(AiProviderSettingsReady(event.config, message: 'Enter both a model ID and API key.'));
      return;
    }
    emit(AiProviderSettingsReady(event.config, isTesting: true));
    try {
      await _factory.create(event.config).sendTextPrompt('Reply with exactly: connected');
      emit(AiProviderSettingsReady(event.config, message: 'Connection successful.'));
    } catch (_) {
      emit(AiProviderSettingsReady(event.config, message: 'Connection failed. Check provider, model, URL, and key.'));
    }
  }
}
