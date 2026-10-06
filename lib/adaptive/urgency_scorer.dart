class UrgencyScorer {

  static double score(String query) {

    print("URGENCY INPUT = $query");

  final q = query.toLowerCase();

    double score = 0.0;

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
      "heart attack",
      "cpr",
      "severe bleeding",
    ];

    const stressedWords = [
      "burn",
      "fracture",
      "pain",
      "panic",
      "dizzy",
      "fainted",
      "heat stroke",
      "heat exhaustion",
    ];

    for(final word in criticalWords) {
      if(q.contains(word)) {
        score += 0.4;
      }
    }

    for(final word in stressedWords) {
      if(q.contains(word)) {
        score += 0.15;
      }
    }

    if(score > 1.0) {
      score = 1.0;
    }
    print("URGENCY RESULT = $score");
    return score;
  }
}