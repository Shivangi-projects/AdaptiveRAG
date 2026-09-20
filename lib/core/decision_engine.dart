import 'query_state.dart';
import 'runtime_config.dart';

class DecisionEngine {
  static RuntimeConfig getConfig(QueryState state) {
    switch (state) {

      case QueryState.normal:
        return const RuntimeConfig(
          topK: 3,
          maxChunks: 2,
          embeddingModel: "MiniLM",
          compressionLevel: 3,
        );

      case QueryState.stressed:
        return const RuntimeConfig(
          topK: 5,
          maxChunks: 4,
          embeddingModel: "MiniLM",
          compressionLevel: 2,
        );

      case QueryState.critical:
        return const RuntimeConfig(
          topK: 10,
          maxChunks: 8,
          embeddingModel: "MiniLM",
          compressionLevel: 1,
        );
    }
  }
}