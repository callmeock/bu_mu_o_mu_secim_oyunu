import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../ad_units.dart';
import 'analytics_helper.dart';

/// AdMob: kategori açmak için **ödüllü geçiş (Rewarded Interstitial)** reklamı.
class AdService {
  static RewardedInterstitialAd? _rewardedInterstitialAd;
  static bool _isCategoryUnlockAdReady = false;
  static Future<void>? _rewardedLoadFuture;

  /// Banner Ad
  static BannerAd? _bannerAd;
  static bool _isBannerReady = false;

  static void _log(String message) {
    // Release dahil cihaz loglarında görünsün (Xcode / logcat).
    // ignore: avoid_print
    print('[AdMob] $message');
  }

  static String get _bannerAdUnitId =>
      AdMobAdUnits.bannerFixed(useTestAds: kDebugMode);

  static String get _categoryUnlockAdUnitId =>
      AdMobAdUnits.rewardedInterstitial(useTestAds: kDebugMode);

  /// Ödüllü geçiş reklamını önceden yükle (kategori açma).
  static Future<void> loadRewardedInterstitialAd() async {
    if (_isCategoryUnlockAdReady && _rewardedInterstitialAd != null) {
      _log('rewarded_interstitial load skipped (already loaded)');
      return;
    }

    if (_rewardedLoadFuture != null) {
      _log('rewarded_interstitial load awaiting in-flight');
      await _rewardedLoadFuture;
      return;
    }

    _rewardedLoadFuture = _performRewardedInterstitialLoad();
    try {
      await _rewardedLoadFuture;
    } finally {
      _rewardedLoadFuture = null;
    }
  }

  static Future<void> _performRewardedInterstitialLoad() async {
    final unitId = _categoryUnlockAdUnitId;
    final modeLabel = kDebugMode ? 'test' : 'production';

    _log(
      'rewarded_interstitial load START | unit=$unitId | mode=$modeLabel | '
      'AdRequest()',
    );

    try {
      await RewardedInterstitialAd.load(
        adUnitId: unitId,
        request: const AdRequest(),
        rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _rewardedInterstitialAd = ad;
            _isCategoryUnlockAdReady = true;
            _log('rewarded_interstitial load SUCCESS | unit=$unitId');
          },
          onAdFailedToLoad: (error) {
            _isCategoryUnlockAdReady = false;
            _log(
              'rewarded_interstitial load FAIL | unit=$unitId | '
              'code=${error.code} | domain=${error.domain} | '
              '${error.message}',
            );
          },
        ),
      );
    } catch (e, st) {
      _isCategoryUnlockAdReady = false;
      _log('rewarded_interstitial load EXCEPTION | $e | $st');
    }
  }

  /// Kategori açma reklamını göster. Ödül kazanılırsa `true`.
  static Future<bool> showRewardedInterstitialAd({
    String placement = 'unknown',
    String adType = 'rewarded_interstitial',
  }) async {
    if (!_isCategoryUnlockAdReady || _rewardedInterstitialAd == null) {
      await loadRewardedInterstitialAd();
      if (!_isCategoryUnlockAdReady || _rewardedInterstitialAd == null) {
        _log(
          'rewarded_interstitial show ABORT (not loaded after load) | '
          'placement=$placement',
        );
        return false;
      }
    }

    final unitId = _categoryUnlockAdUnitId;
    final modeLabel = kDebugMode ? 'test' : 'production';
    _log(
      'rewarded_interstitial show ATTEMPT | placement=$placement | '
      'unit=$unitId | mode=$modeLabel',
    );

    final completer = Completer<bool>();
    var rewardEarned = false;

    await AnalyticsHelper.adOpened(
      placement: placement,
      adType: adType,
    );

    _rewardedInterstitialAd!.fullScreenContentCallback =
        FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        AnalyticsHelper.adClosed(
          placement: placement,
          adType: adType,
          rewardEarned: rewardEarned,
        );
        ad.dispose();
        _rewardedInterstitialAd = null;
        _isCategoryUnlockAdReady = false;
        if (!completer.isCompleted) {
          completer.complete(rewardEarned);
        }
        _log(
          'rewarded_interstitial dismissed | placement=$placement | '
          'reward_earned=$rewardEarned',
        );
        loadRewardedInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        AnalyticsHelper.adClosed(
          placement: placement,
          adType: adType,
          rewardEarned: false,
        );
        ad.dispose();
        _rewardedInterstitialAd = null;
        _isCategoryUnlockAdReady = false;
        if (!completer.isCompleted) {
          completer.complete(false);
        }
        _log(
          'rewarded_interstitial show FAIL | placement=$placement | '
          'code=${error.code} | ${error.message}',
        );
        loadRewardedInterstitialAd();
      },
    );

    _rewardedInterstitialAd!.show(
      onUserEarnedReward: (ad, reward) {
        rewardEarned = true;
        _log(
          'rewarded_interstitial REWARD EARNED | placement=$placement | '
          'type=${reward.type} | amount=${reward.amount}',
        );
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      },
    );

    return completer.future;
  }

  /// Kategori kilidi reklamı hazır mı (isteğe bağlı kontrol).
  static bool get isCategoryUnlockAdReady => _isCategoryUnlockAdReady;

  /// Uygulama açılışında kategori kilidi reklamını önceden yükle.
  static Future<void> initialize() async {
    await loadRewardedInterstitialAd();
  }

  /// Banner ad yükle.
  /// [forceNewLoad]: mevcut banner'ı dispose edip yeni istek atar (ör. periyodik yenileme).
  static Future<void> loadBannerAd({
    required AdSize adSize,
    required Function(BannerAd) onAdLoaded,
    required Function(LoadAdError) onAdFailedToLoad,
    bool forceNewLoad = false,
  }) async {
    if (forceNewLoad) {
      disposeBannerAd();
    } else if (_isBannerReady && _bannerAd != null) {
      onAdLoaded(_bannerAd!);
      return;
    }

    try {
      final adUnitId = _bannerAdUnitId;
      _log('banner load START | unit=$adUnitId | test=$kDebugMode');

      _bannerAd = BannerAd(
        adUnitId: adUnitId,
        size: adSize,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            _isBannerReady = true;
            _log('banner load SUCCESS | unit=$adUnitId');
            onAdLoaded(ad as BannerAd);
          },
          onAdFailedToLoad: (ad, error) {
            _isBannerReady = false;
            _log(
              'banner load FAIL | unit=$adUnitId | '
              'code=${error.code} | ${error.message}',
            );
            ad.dispose();
            onAdFailedToLoad(error);
          },
          onAdOpened: (ad) {
            _log('banner opened');
          },
          onAdClosed: (ad) {
            _log('banner closed');
          },
        ),
      );

      await _bannerAd!.load();
    } catch (e) {
      _log('banner load EXCEPTION | $e');
      onAdFailedToLoad(LoadAdError(
        -1,
        'banner_load_error',
        e.toString(),
        null,
      ));
    }
  }

  /// Banner ad dispose et
  static void disposeBannerAd() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _isBannerReady = false;
  }
}
