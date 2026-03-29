import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  // IDs AdMob pour Le P'tit Cash
  static const String rewardedChestId =
      'ca-app-pub-8016803262695056/8005173943';
  static const String rewardedGamesId =
      'ca-app-pub-8016803262695056/5154475864';
  static const String bannerMissionsId =
      'ca-app-pub-8016803262695056/3298468718';
  static const String bannerLeaderboardId =
      'ca-app-pub-8016803262695056/4006219186';

  // Charger une vidéo rewarded
  static Future<RewardedAd?> loadRewardedAd(String adUnitId) async {
    RewardedAd? rewardedAd;

    await RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          rewardedAd = ad;
          print('✅ Rewarded ad loaded: $adUnitId');
        },
        onAdFailedToLoad: (error) {
          print('❌ Failed to load rewarded ad: $error');
        },
      ),
    );

    return rewardedAd;
  }

  // Afficher une vidéo rewarded
  static Future<bool> showRewardedAd(
    RewardedAd? ad,
    Function(int) onRewarded,
  ) async {
    if (ad == null) return false;

    bool rewarded = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        print('❌ Failed to show rewarded ad: $error');
        ad.dispose();
      },
    );

    await ad.show(
      onUserEarnedReward: (ad, reward) {
        rewarded = true;
        onRewarded(reward.amount.toInt());
        print('✅ User earned reward: ${reward.amount}');
      },
    );

    return rewarded;
  }

  // Charger une bannière
  static BannerAd loadBannerAd(String adUnitId, Function(bool) onLoaded) {
    return BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          print('✅ Banner ad loaded: $adUnitId');
          onLoaded(true);
        },
        onAdFailedToLoad: (ad, error) {
          print('❌ Failed to load banner ad: $error');
          ad.dispose();
          onLoaded(false);
        },
      ),
    )..load();
  }
}
