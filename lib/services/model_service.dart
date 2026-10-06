import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_llama/flutter_llama.dart';
import '../core/state_analyzer.dart';
import '../core/decision_engine.dart';
import '../adaptive/urgency_scorer.dart';

class ModelService {
  bool _isReady = false;
  String _errorMessage = '';

  bool get isReady => _isReady;
  String get errorMessage => _errorMessage;

  /// Loads the GGUF model into memory
  Future<bool> loadModel({
  required String modelPath,
  required int contextLength,
  required int cpuThreads,
}) async {

  debugPrint(
    "LOAD MODEL INSTANCE = ${identityHashCode(this)}"
  );

  try {
    _errorMessage = '';

    debugPrint("========== MODEL LOAD ==========");
    debugPrint("Path: $modelPath");
    debugPrint("Exists: ${File(modelPath).existsSync()}");
    debugPrint("Context: $contextLength");
    debugPrint("Threads: $cpuThreads");

    final config = LlamaConfig(
      modelPath: modelPath,
      nThreads: cpuThreads,
      nGpuLayers: 0,
    );

    await FlutterLlama.instance.loadModel(config);

    debugPrint("MODEL LOAD SUCCESS");

    _isReady = true;
    return true;
  } catch (e) {
    _isReady = false;
    _errorMessage = e.toString();
    debugPrint('Failed to load model: $e');
    return false;
  }
}

  /// Unloads the model
  Future<void> unloadModel() async {
    try {
      await FlutterLlama.instance.unloadModel();
      _isReady = false;
      _errorMessage = '';
    } catch (e) {
      debugPrint('Failed to unload model: $e');
    }
  }
  Future<String> generateResponse({

  required String prompt,
  required String query,
  required double temperature,
  required int maxTokens,
})async {
  if (!_isReady) {
    throw Exception("Model not loaded");
  }
  final state = StateAnalyzer.analyze(query);

final urgencyScore =
    UrgencyScorer.score(query);

print("URGENCY SCORE = $urgencyScore");
final config = DecisionEngine.getConfig(state);

debugPrint("========== DYNAMIC ENGINE ==========");
debugPrint("Query: $query");
debugPrint("State: $state");
debugPrint("TopK: ${config.topK}");
debugPrint("Chunks: ${config.maxChunks}");
debugPrint("Embedding: ${config.embeddingModel}");
debugPrint("Compression: ${config.compressionLevel}");
debugPrint("====================================");


  final params = GenerationParams(
  prompt: prompt,
  temperature: temperature,
  maxTokens: maxTokens,
  stopSequences: [
    "Question:",
    "Context:",
    "IMPORTANT:"
  ],
);

  final response =
      await FlutterLlama.instance.generate(params);

  return response.text;
}

  /// Runs test inference
  Future<String> testModel() async {
    if (!_isReady) {
      return 'Error: Model is not initialized.';
    }

    try {
      final params = GenerationParams(
        prompt: "Hello",
        maxTokens: 32,
        temperature: 0.0,
      );
      debugPrint("Starting generation...");
      final response = await FlutterLlama.instance.generate(params);
      debugPrint("Generation completed");
debugPrint("Raw response: ${response.text}");
      final text = response.text;

      if (text.trim().isEmpty) {
        return 'Engine returned empty string. Check model format or parameters.';
      }

      return text.trim();
    } catch (e) {
      return 'Execution exception: $e';
    }
  }
}