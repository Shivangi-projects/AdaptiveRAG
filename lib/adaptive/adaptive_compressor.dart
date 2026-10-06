class AdaptiveCompressor {

  static String compress(
    String text,
    double urgency,
  ) {

    final sentences = text.split('.');

    if (urgency >= 0.8) {
      return text;
    }

    if (urgency >= 0.4) {
      return sentences.take(
        (sentences.length * 0.7).ceil(),
      ).join('.');
    }

    return sentences.take(
      (sentences.length * 0.3).ceil(),
    ).join('.');
  }
}