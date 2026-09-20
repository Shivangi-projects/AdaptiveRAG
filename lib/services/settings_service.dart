import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';

class SettingsService {
  static const _keyModelPath = 'edgerag_model_path';
  static const _keyModelName = 'edgerag_model_name';
  static const _keyCpuThreads = 'edgerag_cpu_threads';
  static const _keyContextLength = 'edgerag_context_length';
  static const _keyMaxTokens = 'edgerag_max_tokens';
  static const _keyTemperature = 'edgerag_temperature';
  static const _keyTopK = 'edgerag_top_k';
  static const _keyChunkSize = 'edgerag_chunk_size';
  static const _keyChunkOverlap = 'edgerag_chunk_overlap';
  static const _keyIsDemoMode = 'edgerag_is_demo_mode';
  static const _keyIsFirstRun = 'edgerag_is_first_run';

  AppSettings _settings = AppSettings();
  AppSettings get settings => _settings;

  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _settings = AppSettings(
        ggufModelPath: prefs.getString(_keyModelPath) ?? '',
        ggufModelName: prefs.getString(_keyModelName) ?? 'No Model Selected',
        cpuThreads: prefs.getInt(_keyCpuThreads) ?? 4,
        contextLength: prefs.getInt(_keyContextLength) ?? 1024,
        maxTokens: prefs.getInt(_keyMaxTokens) ?? 64,
        temperature: prefs.getDouble(_keyTemperature) ?? 0.7,
        topK: (prefs.getInt(_keyTopK) ?? 3).clamp(1, 5),
        chunkSize: prefs.getInt(_keyChunkSize) ?? 350,
        chunkOverlap: prefs.getInt(_keyChunkOverlap) ?? 35,
        isDemoMode: prefs.getBool(_keyIsDemoMode) ?? false,
        isFirstRun: prefs.getBool(_keyIsFirstRun) ?? true,
      );
    } catch (_) {
      _settings = AppSettings();
    }
  }

  Future<void> saveSettings(AppSettings newSettings) async {
    _settings = newSettings;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyModelPath, newSettings.ggufModelPath);
      await prefs.setString(_keyModelName, newSettings.ggufModelName);
      await prefs.setInt(_keyCpuThreads, newSettings.cpuThreads);
      await prefs.setInt(_keyContextLength, newSettings.contextLength);
      await prefs.setInt(_keyMaxTokens, newSettings.maxTokens);
      await prefs.setDouble(_keyTemperature, newSettings.temperature);
      await prefs.setInt(_keyTopK, newSettings.topK);
      await prefs.setInt(_keyChunkSize, newSettings.chunkSize);
      await prefs.setInt(_keyChunkOverlap, newSettings.chunkOverlap);
      await prefs.setBool(_keyIsDemoMode, newSettings.isDemoMode);
      await prefs.setBool(_keyIsFirstRun, newSettings.isFirstRun);
    } catch (_) {}
  }

  Future<void> completeOnboarding() async {
    await saveSettings(_settings.copyWith(isFirstRun: false));
  }
}
