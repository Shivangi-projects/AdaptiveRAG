import 'chunk.dart';

class QueryResult {
  final String question;
  final String answer;
  final List<ChunkItem> sources;
  final int embeddingTimeMs;
  final int searchTimeMs;
  final int generationTimeMs;
  final int totalTimeMs;
  final double tokensPerSecond;
  final bool isRetrievalOnly;
  final DateTime timestamp;

  QueryResult({
    required this.question,
    required this.answer,
    required this.sources,
    this.embeddingTimeMs = 0,
    this.searchTimeMs = 0,
    this.generationTimeMs = 0,
    this.totalTimeMs = 0,
    this.tokensPerSecond = 0.0,
    this.isRetrievalOnly = false,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'answer': answer,
      'sources': sources.map((s) => s.toJson()).toList(),
      'embedding_time_ms': embeddingTimeMs,
      'search_time_ms': searchTimeMs,
      'generation_time_ms': generationTimeMs,
      'total_time_ms': totalTimeMs,
      'tokens_per_second': tokensPerSecond,
      'is_retrieval_only': isRetrievalOnly,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
