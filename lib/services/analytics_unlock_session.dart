/// Bu app oturumunda reklamla açılan kategori anahtarları (category_play_started için).
class AnalyticsUnlockSession {
  AnalyticsUnlockSession._();

  static final Set<String> _unlockedKeys = {};

  static void markUnlocked(String categoryKey) {
    _unlockedKeys.add(categoryKey);
  }

  static bool unlockedThisSession(String categoryKey) =>
      _unlockedKeys.contains(categoryKey);
}
