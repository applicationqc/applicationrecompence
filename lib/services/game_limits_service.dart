import 'package:shared_preferences/shared_preferences.dart';

class GameLimitsService {
  // LIMITES QUOTIDIENNES POUR RENTABILITÉ
  static const int scratchCardDailyLimit = 5; // 5 parties/jour
  static const int memoryGameDailyLimit = 3; // 3 parties/jour
  static const int clickerGameDailyLimit = 3; // 3 parties/jour

  static const String _scratchKey = 'scratch_plays_';
  static const String _memoryKey = 'memory_plays_';
  static const String _clickerKey = 'clicker_plays_';

  static Future<bool> canPlayScratchCard() async {
    return await _canPlay(_scratchKey, scratchCardDailyLimit);
  }

  static Future<bool> canPlayMemory() async {
    return await _canPlay(_memoryKey, memoryGameDailyLimit);
  }

  static Future<bool> canPlayClicker() async {
    return await _canPlay(_clickerKey, clickerGameDailyLimit);
  }

  static Future<int> getScratchPlaysLeft() async {
    return await _getPlaysLeft(_scratchKey, scratchCardDailyLimit);
  }

  static Future<int> getMemoryPlaysLeft() async {
    return await _getPlaysLeft(_memoryKey, memoryGameDailyLimit);
  }

  static Future<int> getClickerPlaysLeft() async {
    return await _getPlaysLeft(_clickerKey, clickerGameDailyLimit);
  }

  static Future<void> recordScratchPlay() async {
    await _recordPlay(_scratchKey);
  }

  static Future<void> recordMemoryPlay() async {
    await _recordPlay(_memoryKey);
  }

  static Future<void> recordClickerPlay() async {
    await _recordPlay(_clickerKey);
  }

  // Méthodes privées
  static Future<bool> _canPlay(String key, int limit) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _getToday();
    final plays = prefs.getInt('$key$today') ?? 0;
    return plays < limit;
  }

  static Future<int> _getPlaysLeft(String key, int limit) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _getToday();
    final plays = prefs.getInt('$key$today') ?? 0;
    return limit - plays;
  }

  static Future<void> _recordPlay(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _getToday();
    final plays = prefs.getInt('$key$today') ?? 0;
    await prefs.setInt('$key$today', plays + 1);
  }

  static String _getToday() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  // Réinitialiser les compteurs (pour testing)
  static Future<void> resetAllLimits() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _getToday();
    await prefs.remove('$_scratchKey$today');
    await prefs.remove('$_memoryKey$today');
    await prefs.remove('$_clickerKey$today');
  }
}
