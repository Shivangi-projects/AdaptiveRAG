import '../lib/adaptive/urgency_scorer.dart';
import '../lib/core/state_analyzer.dart';

void main() {
  const queries = [
    'Bleeding',
    'Severe bleeding',
    'What should I do for pain?',
    'How do I change a bandage?',
    'Person is not breathing',
  ];

  for (final query in queries) {
    final score = UrgencyScorer.score(query);
    final state = StateAnalyzer.analyze(query);

    print('Query: $query');
    print('Urgency score: $score');
    print('Query state: $state');
    print('--------------------');
  }
}
