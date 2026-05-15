import 'dart:math';

/// Cold start başına tek oturum kimliği; tüm analytics event'lerine eklenir.
class AnalyticsSession {
  AnalyticsSession._();

  static String? _id;

  static String get id => _id ??= _generate();

  /// [main] içinde açıkça çağrılabilir (cold start).
  static void start() {
    _id = _generate();
  }

  static String _generate() =>
      '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(0x7fffffff)}';
}
