
class UrgencyScorer {
  static double score(String query) {
    final q = query.toLowerCase();

    const criticalWords = [
      "not breathing",
      "cardiac arrest",
      "heart attack",
      "unconscious",
      "poisoning",
      "poisoned",
      "overdose",
      "snake bite",
      "burn",
      "electrocution",
      "shock",
      "seizure",
      "stroke",
      "cpr",
      "bleeding",
    ];

    const stressedWords = [
      "fracture",
      "pain",
      "panic",
      "dizzy",
      "fainted",
      "heat stroke",
      "heat exhaustion",
      "injury",
    ];

    for (final word in criticalWords) {
      if (q.contains(word)) {
        return 0.8;
      }
    }

    for (final word in stressedWords) {
      if (q.contains(word)) {
        return 0.4;
      }
    }

    return 0.0;
  }
}
