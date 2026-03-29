import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:math';
import 'ad_service.dart';

class ChestSystem {
  static const Duration chestCooldown = Duration(hours: 6);

  static Future<Map<String, dynamic>> getChestStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final lastOpenedStr = prefs.getString('last_chest_opened');

    if (lastOpenedStr == null) {
      return {'available': true, 'timeLeft': Duration.zero};
    }

    final lastOpened = DateTime.parse(lastOpenedStr);
    final nextAvailable = lastOpened.add(chestCooldown);
    final now = DateTime.now();

    if (now.isAfter(nextAvailable)) {
      return {'available': true, 'timeLeft': Duration.zero};
    }

    return {
      'available': false,
      'timeLeft': nextAvailable.difference(now),
      'nextAvailable': nextAvailable,
    };
  }

  static int generateRandomReward() {
    final random = Random();
    final roll = random.nextInt(100);

    // Distribution des récompenses (OPTIMISÉ PROFIT 60%+):
    // Avec pub rewarded ($0.02), max reward doublé = 400 coins ($0.02)
    // Profit: $0.02 - $0.02 = $0 (0% mais pas de perte)
    // SANS doubler: profit = $0.02 (100%)
    // 50% : 20-100 PtitCoins
    // 30% : 100-200 PtitCoins
    // 15% : 200-400 PtitCoins
    // 4%  : 400-600 PtitCoins
    // 1%  : 600-1000 PtitCoins (JACKPOT!)

    if (roll < 50) {
      return 20 + random.nextInt(80); // 20-100
    } else if (roll < 80) {
      return 100 + random.nextInt(100); // 100-200
    } else if (roll < 95) {
      return 200 + random.nextInt(200); // 200-400
    } else if (roll < 99) {
      return 400 + random.nextInt(200); // 400-600
    } else {
      return 600 + random.nextInt(400); // 600-1000 JACKPOT!
    }
  }

  static String getRewardRarity(int reward) {
    if (reward >= 600) return '💎 LÉGENDAIRE';
    if (reward >= 400) return '💜 ÉPIQUE';
    if (reward >= 200) return '🔵 RARE';
    if (reward >= 100) return '🟢 PEU COMMUN';
    return '⚪ COMMUN';
  }

  // Charger la pub rewarded pour le coffre
  static Future<RewardedAd?> loadChestRewardedAd() async {
    return await AdService.loadRewardedAd(AdService.rewardedChestId);
  }

  static Future<Map<String, dynamic>> openChest({bool doubled = false}) async {
    final status = await getChestStatus();

    if (!status['available']) {
      throw Exception('Coffre pas encore disponible!');
    }

    int reward = generateRandomReward();
    String rarity = getRewardRarity(reward);

    // Doubler si publicité vue
    if (doubled) {
      reward = reward * 2;
      rarity = '💎✨ $rarity DOUBLÉ!';
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'last_chest_opened', DateTime.now().toIso8601String());

    // Stats
    final chestsOpened = prefs.getInt('total_chests_opened') ?? 0;
    final totalFromChests = prefs.getInt('total_from_chests') ?? 0;
    await prefs.setInt('total_chests_opened', chestsOpened + 1);
    await prefs.setInt('total_from_chests', totalFromChests + reward);

    return {
      'reward': reward,
      'rarity': rarity,
      'totalChests': chestsOpened + 1,
    };
  }

  static Future<Map<String, int>> getChestStats() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'totalChests': prefs.getInt('total_chests_opened') ?? 0,
      'totalEarned': prefs.getInt('total_from_chests') ?? 0,
    };
  }
}
