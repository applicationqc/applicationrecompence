import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class DailyMission {
  final String id;
  final String title;
  final String description;
  final int targetCount;
  final int reward;
  final String icon;
  int currentProgress;
  bool completed;

  DailyMission({
    required this.id,
    required this.title,
    required this.description,
    required this.targetCount,
    required this.reward,
    required this.icon,
    this.currentProgress = 0,
    this.completed = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'targetCount': targetCount,
        'reward': reward,
        'icon': icon,
        'currentProgress': currentProgress,
        'completed': completed,
      };

  factory DailyMission.fromJson(Map<String, dynamic> json) => DailyMission(
        id: json['id'],
        title: json['title'],
        description: json['description'],
        targetCount: json['targetCount'],
        reward: json['reward'],
        icon: json['icon'],
        currentProgress: json['currentProgress'] ?? 0,
        completed: json['completed'] ?? false,
      );
}

class DailyMissionsService {
  static List<DailyMission> getDefaultMissions() {
    return [
      DailyMission(
        id: 'watch_videos',
        title: 'Vidéothon',
        description: 'Regarde 5 vidéos publicitaires',
        targetCount: 5,
        reward: 200, // Réduit de 60% (500→200)
        icon: '📺',
      ),
      DailyMission(
        id: 'complete_survey',
        title: 'Expert Sondages',
        description: 'Complète 1 sondage',
        targetCount: 1,
        reward: 400, // Réduit de 60% (1000→400)
        icon: '📋',
      ),
      DailyMission(
        id: 'earn_coins',
        title: 'Collectionneur',
        description: 'Gagne 500 PtitCoins', // Objectif réduit aussi
        targetCount: 500,
        reward: 300, // Réduit de 60% (750→300)
        icon: '💰',
      ),
      DailyMission(
        id: 'daily_login',
        title: 'Assidu',
        description: 'Connecte-toi aujourd\'hui',
        targetCount: 1,
        reward: 100, // Réduit de 60% (250→100)
        icon: '⭐',
      ),
    ];
  }

  static Future<List<DailyMission>> loadMissions() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final lastDate = prefs.getString('missions_date') ?? '';

    // Reset missions si nouveau jour
    if (lastDate != today) {
      final missions = getDefaultMissions();
      await saveMissions(missions);
      await prefs.setString('missions_date', today);
      return missions;
    }

    // Charger missions existantes
    final data = prefs.getString('daily_missions');
    if (data == null) return getDefaultMissions();

    final List<dynamic> json = jsonDecode(data);
    return json.map((m) => DailyMission.fromJson(m)).toList();
  }

  static Future<void> saveMissions(List<DailyMission> missions) async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(missions.map((m) => m.toJson()).toList());
    await prefs.setString('daily_missions', data);
  }

  static Future<void> updateProgress(
      String missionId, int progress, Function(int) onComplete) async {
    final missions = await loadMissions();
    final mission = missions.firstWhere((m) => m.id == missionId);

    if (mission.completed) return;

    mission.currentProgress = progress;

    if (mission.currentProgress >= mission.targetCount && !mission.completed) {
      mission.completed = true;
      onComplete(mission.reward);
      print(
          '🎉 Mission complétée: ${mission.title} (+${mission.reward} PtitCoins)');
    }

    await saveMissions(missions);
  }

  static Future<int> getCompletedCount() async {
    final missions = await loadMissions();
    return missions.where((m) => m.completed).length;
  }

  static Future<int> getTotalRewardsAvailable() async {
    final missions = await loadMissions();
    return missions
        .where((m) => !m.completed)
        .fold<int>(0, (sum, m) => sum + m.reward);
  }
}
