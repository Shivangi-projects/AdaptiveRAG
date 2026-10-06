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
    double urgencyScore,
  ) {

    if(urgencyScore >= 0.8) {
      return const FidelityConfig(
        fidelityScore: 1.0,
        compressionLevel: 1,
        topK: 10,
      );
    }

    if(urgencyScore >= 0.4) {
      return const FidelityConfig(
        fidelityScore: 0.7,
        compressionLevel: 2,
        topK: 5,
      );
    }

    return const FidelityConfig(
      fidelityScore: 0.3,
      compressionLevel: 3,
      topK: 3,
    );
  }
}