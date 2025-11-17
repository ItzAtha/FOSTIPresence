class StringSimilar {
  // Calculate the similarity between two strings using the Jaccard index.
  // Returns a value between 0.0 (no similarity) and 1.0 (identical).
  static double jaccardSimilarity(String str1, String str2) {
    final set1 = str1.toLowerCase().split('').toSet();
    final set2 = str2.toLowerCase().split('').toSet();

    final intersection = set1.intersection(set2).length;
    final union = set1.union(set2).length;

    if (union == 0) return 1.0; // Both strings are empty

    return intersection / union;
  }
}
