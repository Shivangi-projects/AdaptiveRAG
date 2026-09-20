class PerfMetrics {
  final int queryEmbeddingMs;
  final int vectorSearchMs;
  final int retrievalLatencyMs;
  final int timeToFirstTokenMs;
  final double tokensPerSecond;
  final int totalLatencyMs;
  final int ramUsageBytes;
  final int databaseSizeBytes;
  final int totalDocuments;
  final int totalChunks;

  PerfMetrics({
    this.queryEmbeddingMs = 0,
    this.vectorSearchMs = 0,
    this.retrievalLatencyMs = 0,
    this.timeToFirstTokenMs = 0,
    this.tokensPerSecond = 0.0,
    this.totalLatencyMs = 0,
    this.ramUsageBytes = 0,
    this.databaseSizeBytes = 0,
    this.totalDocuments = 0,
    this.totalChunks = 0,
  });

  String get formattedRam {
    if (ramUsageBytes <= 0) return 'N/A';
    final mb = ramUsageBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  String get formattedDbSize {
    if (databaseSizeBytes < 1024) return '$databaseSizeBytes B';
    if (databaseSizeBytes < 1024 * 1024) return '${(databaseSizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(databaseSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}
