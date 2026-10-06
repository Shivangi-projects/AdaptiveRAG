import 'query_state.dart';

class StateAnalyzer {
  static QueryState analyze(String query) {
    final q = query.toLowerCase();

    const criticalWords = [
  "unconscious",
  "not breathing",
  "cardiac arrest",
  "heart attack",
  "severe bleeding",
  "medical emergency",
  "cpr",

  "poisoning",
  "poisoned",
  "overdose",
  "snake bite",
  "burn",
  "electrocution",
  "shock",
  "seizure",
  "stroke",
];

    const stressedWords = [
      "dizzy",
      "fainted",
      "heat exhaustion",
      "heat stroke",
      "panic",
      "injury",
      "pain",
      "burn",
      "fracture",
    ];

    for (final word in criticalWords) {
      if (q.contains(word)) {
        return QueryState.critical;
      }
    }

    for (final word in stressedWords) {
      if (q.contains(word)) {
        return QueryState.stressed;
      }
    }

    return QueryState.normal;
  }
}