import '../models/perf_metrics.dart';
import '../models/query_result.dart';
import 'native_bridge.dart';

class BenchmarkService {
  final NativeBridge _bridge = NativeBridge();
  final List<QueryResult> _recentQueries = [];

  List<QueryResult> get recentQueries => List.unmodifiable(_recentQueries);

  void recordQuery(QueryResult result) {
    _recentQueries.insert(0, result);
    if (_recentQueries.length > 20) {
      _recentQueries.removeLast();
    }
  }

  PerfMetrics getLatestMetrics() {
    final stats = _bridge.getStats();
    if (_recentQueries.isEmpty) {
      return PerfMetrics(
        databaseSizeBytes: stats['db_size'] ?? 0,
        totalDocuments: stats['doc_count'] ?? 0,
        totalChunks: stats['chunk_count'] ?? 0,
      );
    }

    final latest = _recentQueries.first;
    return PerfMetrics(
      queryEmbeddingMs: latest.embeddingTimeMs,
      vectorSearchMs: latest.searchTimeMs,
      retrievalLatencyMs: latest.embeddingTimeMs + latest.searchTimeMs,
      timeToFirstTokenMs: latest.generationTimeMs > 0 ? (latest.generationTimeMs ~/ 3) : 0,
      tokensPerSecond: latest.tokensPerSecond,
      totalLatencyMs: latest.totalTimeMs,
      databaseSizeBytes: stats['db_size'] ?? 0,
      totalDocuments: stats['doc_count'] ?? 0,
      totalChunks: stats['chunk_count'] ?? 0,
    );
  }
}
