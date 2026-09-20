class RuntimeConfig {
  final int topK;
  final int maxChunks;
  final String embeddingModel;
  final int compressionLevel;

  const RuntimeConfig({
    required this.topK,
    required this.maxChunks,
    required this.embeddingModel,
    required this.compressionLevel,
  });
}