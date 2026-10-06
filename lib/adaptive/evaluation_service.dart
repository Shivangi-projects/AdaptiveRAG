class EvaluationResult {
  final String query;
  final String expectedDocument;
  final String retrievedDocument;
  final double score;
  final bool hit;

  const EvaluationResult({
    required this.query,
    required this.expectedDocument,
    required this.retrievedDocument,
    required this.score,
    required this.hit,
  });
}

class EvaluationService {
  final List<EvaluationResult> _results = [];

  void record({
    required String query,
    required String expectedDocument,
    required String retrievedDocument,
    required double score,
  }) {
    _results.add(
      EvaluationResult(
        query: query,
        expectedDocument: expectedDocument,
        retrievedDocument: retrievedDocument,
        score: score,
        hit: expectedDocument == retrievedDocument,
      ),
    );
  }

  int get totalQueries => _results.length;

  int get hits =>
      _results.where((r) => r.hit).length;

  double get accuracy {
    if (_results.isEmpty) return 0.0;
    return hits / _results.length;
  }

  double get averageScore {
    if (_results.isEmpty) return 0.0;

    double total = 0.0;

    for (final r in _results) {
      total += r.score;
    }

    return total / _results.length;
  }

  double recallAtK(
    List<String> retrievedDocs,
    String expectedDoc,
  ) {
    return retrievedDocs.contains(expectedDoc)
        ? 1.0
        : 0.0;
  }

  void clear() {
    _results.clear();
  }

  void printReport() {
    print("");
    print("==================================");
    print("      RETRIEVAL EVALUATION");
    print("==================================");

    print("Queries Tested : $totalQueries");
    print("Correct Hits   : $hits");

    print(
      "Accuracy       : ${(accuracy * 100).toStringAsFixed(2)}%",
    );

    print(
      "Average Score  : ${averageScore.toStringAsFixed(4)}",
    );

    print("----------------------------------");

    for (final r in _results) {
      print("Query     : ${r.query}");
      print("Expected  : ${r.expectedDocument}");
      print("Retrieved : ${r.retrievedDocument}");
      print("Score     : ${r.score.toStringAsFixed(4)}");
      print("Hit       : ${r.hit}");
      print("----------------------------------");
    }

    print("==================================");
  }
}