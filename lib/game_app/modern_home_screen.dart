import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../widgets/app_background.dart';
import '../services/user_progress_service.dart';
import '../services/daily_missions_service.dart';
import '../services/streak_service.dart';
import '../services/chest_system.dart';
import '../services/referral_service.dart';
import '../services/ad_service.dart';
import 'leaderboard_screen.dart';
import '../mini_games/scratch_card_game.dart';
import '../mini_games/memory_game.dart';
import '../mini_games/clicker_game.dart';

class ModernHomeScreen extends StatefulWidget {
  final int score;
  final Function(int) onScoreUpdate;

  const ModernHomeScreen({
    super.key,
    required this.score,
    required this.onScoreUpdate,
  });

  @override
  State<ModernHomeScreen> createState() => _ModernHomeScreenState();
}

class _ModernHomeScreenState extends State<ModernHomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  Map<String, dynamic> userProgress = {};
  List<DailyMission> missions = [];
  Map<String, dynamic> chestStatus = {};
  Map<String, dynamic> streakData = {};
  Map<String, dynamic> referralStats = {};
  bool loading = true;
  
  BannerAd? _topBannerAd;
  BannerAd? _bottomBannerAd;
  bool _isTopBannerReady = false;
  bool _isBottomBannerReady = false;
  
  final String _topBannerUnitId = 'ca-app-pub-8016803262695056/5875518835';
  final String _bottomBannerUnitId = 'ca-app-pub-8016803262695056/1064021761';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    // Ne pas bloquer l'affichage - charger en arrière-plan
    _loadAllData();
    _loadTopBanner();
    _loadBottomBanner();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _topBannerAd?.dispose();
    _bottomBannerAd?.dispose();
    super.dispose();
  }

  void _loadTopBanner() {
    _topBannerAd = BannerAd(
      adUnitId: _topBannerUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _isTopBannerReady = true),
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          print('Erreur bannière top home: $err');
        },
      ),
    )..load();
  }

  void _loadBottomBanner() {
    _bottomBannerAd = BannerAd(
      adUnitId: _bottomBannerUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _isBottomBannerReady = true),
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          print('Erreur bannière bottom home: $err');
        },
      ),
    )..load();
  }

  Future<void> _loadAllData() async {
    // Charger les données en PARALLÈLE pour plus de rapidité
    final results = await Future.wait([
      UserProgressService.getUserProgress(),
      DailyMissionsService.loadMissions(),
      ChestSystem.getChestStatus(),
      StreakService.updateStreak(),
      ReferralService.getReferralStats(),
    ]);

    setState(() {
      userProgress = results[0] as Map<String, dynamic>;
      missions = results[1] as List<DailyMission>;
      chestStatus = results[2] as Map<String, dynamic>;
      streakData = results[3] as Map<String, dynamic>;
      referralStats = results[4] as Map<String, dynamic>;
      loading = false;
    });

    // Afficher le bonus de streak
    if (streakData['newStreak'] == true && streakData['bonus'] > 0) {
      _showStreakBonus();
    }
  }

  void _showStreakBonus() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.orange.shade900,
        title: Row(
          children: [
            Text(streakData['emoji'] ?? '🔥'),
            const SizedBox(width: 10),
            const Text('Bonus de Connexion!'),
          ],
        ),
        content: Text(
          'Jour ${streakData['streak']} consécutif!\n+${streakData['bonus']} PtitCoins bonus!',
          style: const TextStyle(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onScoreUpdate(streakData['bonus']);
            },
            child: const Text('Super!', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _openChest() async {
    try {
      // Demander si l'utilisateur veut voir une pub pour doubler
      final watchAd = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.purple.shade900,
          title: const Text('🎁 Ouvrir le Coffre'),
          content: const Text(
            'Veux-tu regarder une publicité pour DOUBLER ta récompense? 📺',
            style: TextStyle(fontSize: 18),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Non merci',
                  style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('OUI! Doubler x2',
                  style: TextStyle(
                      color: Colors.yellow, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (watchAd == null) return;

      RewardedAd? rewardedAd;
      if (watchAd) {
        // Charger la pub
        rewardedAd = await ChestSystem.loadChestRewardedAd();
        if (rewardedAd != null) {
          await AdService.showRewardedAd(rewardedAd, (amount) {});
        }
      }

      final result =
          await ChestSystem.openChest(doubled: watchAd && rewardedAd != null);

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.purple.shade900,
          title: const Text('🎁 Coffre Ouvert!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                result['rarity'],
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Image.asset('assets/images/ptitcoin.png', width: 60, height: 60),
              const SizedBox(height: 10),
              Text(
                '+${result['reward']} PtitCoins!',
                style:
                    const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onScoreUpdate(result['reward']);
                _loadAllData();
              },
              child: const Text('Récupérer!',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _playScratchCard() async {
    final result = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (context) => ScratchCardGame(
          onWin: (prize) => widget.onScoreUpdate(prize),
        ),
      ),
    );

    if (result != null) {
      widget.onScoreUpdate(result);
    }
  }

  Future<void> _playMemoryGame() async {
    final result = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (context) => MemoryGame(
          onWin: (prize) => widget.onScoreUpdate(prize),
        ),
      ),
    );

    if (result != null) {
      widget.onScoreUpdate(result);
    }
  }

  Future<void> _playClickerGame() async {
    final result = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (context) => ClickerGame(
          onWin: (prize) => widget.onScoreUpdate(prize),
        ),
      ),
    );

    if (result != null) {
      widget.onScoreUpdate(result);
    }
  }

  void _showReferralDialog() {
    final code = referralStats['code'] ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('👥 Parrainage'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ton code de parrainage:'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    code,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code copié!')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Filleuls: ${referralStats['count']}'),
            Text('Gains: ${referralStats['earnings']} PtitCoins'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.person, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                FirebaseAuth.instance.currentUser?.email ?? 'Utilisateur',
                style: const TextStyle(color: Colors.white, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard, color: Colors.orange),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const LeaderboardScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadAllData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Bannière du haut
                  if (_isTopBannerReady && _topBannerAd != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      height: 50,
                      child: AdWidget(ad: _topBannerAd!),
                    ),
                  // Splash Image
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/images/splash_colorful.png',
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  _buildBalanceCard(),
                  const SizedBox(height: 16),
                  _buildProgressCard(),
                  const SizedBox(height: 16),
                  _buildStreakCard(),
                  const SizedBox(height: 16),
                  _buildChestCard(),
                  const SizedBox(height: 16),
                  _buildMissionsCard(),
                  const SizedBox(height: 16),
                  _buildQuickActionsCard(),
                  const SizedBox(height: 16),
                  _buildReferralCard(),
                  const SizedBox(height: 16),
                  // Bannière du bas
                  if (_isBottomBannerReady && _bottomBannerAd != null)
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      height: 50,
                      child: AdWidget(ad: _bottomBannerAd!),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.green, Colors.teal],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.5),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Solde Total',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/ptitcoin.png', width: 40, height: 40),
              const SizedBox(width: 10),
              Text(
                '${widget.score}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Text(
            'PtitCoins',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    if (loading) {
      return Card(
        color: Colors.white.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: const Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator(color: Colors.green)),
        ),
      );
    }

    final level = userProgress['level'] ?? 1;
    final xp = userProgress['xp'] ?? 0;
    final xpForNext = userProgress['xpForNext'] ?? 1000;
    final bonus = ((userProgress['bonus'] ?? 1.0) - 1) * 100;

    return Card(
      color: Colors.white.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '⭐ Niveau $level',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '+${bonus.toStringAsFixed(0)}% Bonus',
                  style: const TextStyle(color: Colors.orange, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: xp / xpForNext,
              backgroundColor: Colors.grey.shade800,
              valueColor: const AlwaysStoppedAnimation(Colors.orange),
              minHeight: 10,
            ),
            const SizedBox(height: 5),
            Text(
              '$xp / $xpForNext XP',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakCard() {
    final streak = streakData['streak'] ?? 0;
    final emoji = streakData['emoji'] ?? '⭐';

    return Card(
      color: Colors.orange.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Série Quotidienne',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  Text(
                    '$streak jours consécutifs!',
                    style: const TextStyle(color: Colors.orange, fontSize: 16),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChestCard() {
    final available = chestStatus['available'] ?? false;
    final timeLeft = chestStatus['timeLeft'] ?? Duration.zero;

    return GestureDetector(
      onTap: available ? _openChest : null,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Transform.scale(
            scale: available ? 1.0 + (_pulseController.value * 0.05) : 1.0,
            child: Card(
              color: available
                  ? Colors.purple.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.2),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Text(
                      available ? '🎁✨' : '🎁',
                      style: const TextStyle(fontSize: 50),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Coffre Mystère',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            available
                                ? 'Disponible maintenant!'
                                : 'Disponible dans ${timeLeft.inHours}h ${timeLeft.inMinutes % 60}m',
                            style: TextStyle(
                              color: available ? Colors.green : Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMissionsCard() {
    final completedCount = missions.where((m) => m.completed).length;

    return Card(
      color: Colors.blue.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '📋 Missions Quotidiennes',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$completedCount/${missions.length}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...missions.map((mission) => _buildMissionTile(mission)),
          ],
        ),
      ),
    );
  }

  Widget _buildMissionTile(DailyMission mission) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: mission.completed
            ? Colors.green.withOpacity(0.3)
            : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(mission.icon, style: const TextStyle(fontSize: 30)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mission.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  mission.description,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                if (!mission.completed)
                  LinearProgressIndicator(
                    value: mission.currentProgress / mission.targetCount,
                    backgroundColor: Colors.grey.shade800,
                    valueColor: const AlwaysStoppedAnimation(Colors.blue),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          mission.completed
              ? const Icon(Icons.check_circle, color: Colors.green, size: 30)
              : Text(
                  '+${mission.reward}',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    return Card(
      color: Colors.white.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🎮 Mini-Jeux',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _playScratchCard,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('🎮 Découverte',
                        style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _playMemoryGame,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child:
                        const Text('🧠 Memory', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _playClickerGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('💰 Clicker', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferralCard() {
    return Card(
      color: Colors.green.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: _showReferralDialog,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text('👥', style: TextStyle(fontSize: 40)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Parrainage',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${referralStats['count']} filleuls - ${referralStats['earnings']} PtitCoins',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
