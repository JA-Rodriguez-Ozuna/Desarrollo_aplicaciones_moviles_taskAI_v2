import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static const String _prodBannerId =
      'ca-app-pub-7058005879324612/3014678121';
  static const String _testBannerId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _prodRewardedId =
      'ca-app-pub-7058005879324612/7852071833';
  static const String _testRewardedId =
      'ca-app-pub-3940256099942544/5224354917';

  static String get bannerAdUnitId =>
      kDebugMode ? _testBannerId : _prodBannerId;
  static String get rewardedAdUnitId =>
      kDebugMode ? _testRewardedId : _prodRewardedId;

  RewardedAd? _rewardedAd;

  static Future<void> initialize() async {
    try {
      await MobileAds.instance.initialize().timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  BannerAd loadBannerAd({
    VoidCallback? onLoaded,
    void Function(LoadAdError error)? onFailed,
  }) {
    final BannerAd bannerAd = BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => onLoaded?.call(),
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          ad.dispose();
          onFailed?.call(error);
        },
      ),
    );
    bannerAd.load();
    return bannerAd;
  }

  Future<void> loadRewardedAd({
    VoidCallback? onLoaded,
    void Function(LoadAdError error)? onFailed,
  }) async {
    await RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          _rewardedAd = ad;
          onLoaded?.call();
        },
        onAdFailedToLoad: (LoadAdError error) {
          _rewardedAd = null;
          onFailed?.call(error);
        },
      ),
    );
  }

  /// Shows the preloaded rewarded ad and invokes [onReward] once the user
  /// watches it to completion. If no ad is preloaded, loads one first.
  Future<void> showRewardedAd(VoidCallback onReward) async {
    RewardedAd? ad = _rewardedAd;
    if (ad == null) {
      await loadRewardedAd();
      ad = _rewardedAd;
    }
    if (ad == null) return;

    _rewardedAd = null;
    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdDismissedFullScreenContent: (RewardedAd ad) => ad.dispose(),
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) =>
          ad.dispose(),
    );
    await ad.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) =>
          onReward(),
    );
  }

  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
  }
}
