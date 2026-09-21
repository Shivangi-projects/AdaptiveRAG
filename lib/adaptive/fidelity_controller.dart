import 'query_state.dart';

class FidelityConfig {
  final double fidelityScore;
  final int compressionLevel;
  final int topK;

  const FidelityConfig({
    required this.fidelityScore,
    required this.compressionLevel,
    required this.topK,
  });
}

class FidelityController {

  static FidelityConfig getConfig(
    QueryState state,
  ) {

    switch(state) {

      case QueryState.normal:
        return const FidelityConfig(
          fidelityScore: 0.3,
          compressionLevel: 3,
          topK: 3,
        );

      case QueryState.stressed:
        return const FidelityConfig(
          fidelityScore: 0.7,
          compressionLevel: 2,
          topK: 5,
        );

      case QueryState.critical:
        return const FidelityConfig(
          fidelityScore: 1.0,
          compressionLevel: 1,
          topK: 10,
        );
    }
  }
}