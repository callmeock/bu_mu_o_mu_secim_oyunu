import 'package:flutter/material.dart';
import '../analytics/analytics_constants.dart';
import 'ad_service.dart';
import 'analytics_helper.dart';

/// Kilitli kategori için: funnel event'leri + yükleme sheet'i + ödüllü reklam.
class UnlockAdFlow {
  UnlockAdFlow._();

  static Future<bool> showRewardedForCategory(
    BuildContext context, {
    required String categoryKey,
    required String categoryName,
  }) async {
    final source = AnalyticsNavigationState.currentScreen;
    await AnalyticsHelper.categoryLockedTapped(
      categoryKey: categoryKey,
      categoryName: categoryName,
      sourceScreen: source,
    );
    await AnalyticsHelper.unlockOfferShown(
      categoryKey: categoryKey,
      unlockType: 'rewarded_interstitial',
      adsRequired: 1,
    );
    final sheetStart = DateTime.now();
    await AnalyticsHelper.screenView(
      screenName: AnalyticsScreenNames.unlockSheet,
      source: source,
    );
    if (!context.mounted) return false;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    var watched = false;
    try {
      watched = await AdService.showRewardedInterstitialAd(
        placement: AnalyticsAdPlacement.categoryUnlock,
      );
    } finally {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      await AnalyticsHelper.screenExit(
        screenName: AnalyticsScreenNames.unlockSheet,
        durationMs: DateTime.now().difference(sheetStart).inMilliseconds,
      );
    }
    return watched;
  }
}
