class AppSettings {
  final String ggufModelPath;
  final String ggufModelName;
  final int cpuThreads;
  final int contextLength;
  final int maxTokens;
  final double temperature;
  final int topK;
  final int chunkSize;
  final int chunkOverlap;

  // NEW
  final String embeddingModel;

  final bool isDemoMode;
  final bool isFirstRun;

  AppSettings({
    this.ggufModelPath = '',
    this.ggufModelName = 'No Model Selected',
    this.cpuThreads = 4,
    this.contextLength = 1024,
    this.maxTokens = 48,
    this.temperature = 0.0,
    this.topK = 5,
    this.chunkSize = 200,
    this.chunkOverlap = 35,

    // NEW
    this.embeddingModel = 'MiniLM',

    this.isDemoMode = false,
    this.isFirstRun = true,
  });

  AppSettings copyWith({
    String? ggufModelPath,
    String? ggufModelName,
    int? cpuThreads,
    int? contextLength,
    int? maxTokens,
    double? temperature,
    int? topK,
    int? chunkSize,
    int? chunkOverlap,

    // NEW
    String? embeddingModel,

    bool? isDemoMode,
    bool? isFirstRun,
  }) {
    return AppSettings(
      ggufModelPath: ggufModelPath ?? this.ggufModelPath,
      ggufModelName: ggufModelName ?? this.ggufModelName,
      cpuThreads: cpuThreads ?? this.cpuThreads,
      contextLength: contextLength ?? this.contextLength,
      maxTokens: maxTokens ?? this.maxTokens,
      temperature: temperature ?? this.temperature,
      topK: topK ?? this.topK,
      chunkSize: chunkSize ?? this.chunkSize,
      chunkOverlap: chunkOverlap ?? this.chunkOverlap,

      // NEW
      embeddingModel: embeddingModel ?? this.embeddingModel,

      isDemoMode: isDemoMode ?? this.isDemoMode,
      isFirstRun: isFirstRun ?? this.isFirstRun,
    );
  }
}