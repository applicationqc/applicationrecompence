import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:math';
import '../widgets/app_background.dart';
import '../services/ad_service.dart';
import '../services/game_limits_service.dart';

class MemoryGame extends StatefulWidget {
  final Function(int) onWin;

  const MemoryGame({super.key, required this.onWin});

  @override
  State<MemoryGame> createState() => _MemoryGameState();
}

class _MemoryGameState extends State<MemoryGame> {
  List<String> cardEmojis = ['🎮', '🎯', '🎲', '🎰', '🎪', '🎭', '🎨', '🎬'];
  List<String> gameCards = [];
  List<bool> cardFlips = [];
  List<int> selectedIndexes = [];
  int pairsFound = 0;
  int moves = 0;
  int timeLeft = 90; // 1.5 minutes (réduit pour profit)
  bool gameStarted = false;
  bool gameReady = false;
  bool gameWon = false;

  InterstitialAd? _interstitialAd;
  bool _interstitialLoaded = false;
  RewardedAd? _rewardedAd;
  bool _adLoaded = false;

  @override
  void initState() {
    super.initState();
    _initGame();
    _checkLimitAndLoadAd();
    _loadRewardedAd();
  }

  Future<void> _checkLimitAndLoadAd() async {
    final canPlay = await GameLimitsService.canPlayMemory();
    if (!canPlay) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showLimitReached();
      });
      return;
    }
    await _loadInterstitial();
  }

  Future<void> _loadInterstitial() async {
    await InterstitialAd.load(
      adUnitId: 'ca-app-pub-8016803262695056/4572021934',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialLoaded = true;
          setState(() {});
        },
        onAdFailedToLoad: (error) {
          print('❌ Failed to load interstitial ad: $error');
          _interstitialLoaded = false;
          setState(() {});
        },
      ),
    );
  }

  void _showLimitReached() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('⏰ Limite atteinte'),
        content: const Text(
            'Tu as atteint la limite quotidienne de 3 parties au jeu Mémoire. Reviens demain!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showAdThenStart() async {
    if (_interstitialAd == null) return;

    await _interstitialAd!.show();
    _interstitialAd = null;

    await GameLimitsService.recordMemoryPlay();
    setState(() {
      gameReady = true;
    });
  }

  void _initGame() {
    // Créer paires
    gameCards = [...cardEmojis, ...cardEmojis];
    gameCards.shuffle(Random());
    cardFlips = List.filled(16, false);
    selectedIndexes = [];
    pairsFound = 0;
    moves = 0;
    timeLeft = 90;
    gameStarted = false;
    gameWon = false;
    setState(() {});
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }

  Future<void> _loadRewardedAd() async {
    _rewardedAd = await AdService.loadRewardedAd(
        'ca-app-pub-8016803262695056/9108186836');
    setState(() => _adLoaded = _rewardedAd != null);
  }

  void _startTimer() {
    if (!gameStarted) {
      gameStarted = true;
      _countdown();
    }
  }

  void _countdown() {
    if (timeLeft > 0 && !gameWon) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() => timeLeft--);
          _countdown();
        }
      });
    } else if (timeLeft == 0 && !gameWon) {
      _gameLost();
    }
  }

  void _onCardTap(int index) {
    if (!gameReady) return;
    if (!gameStarted) _startTimer();

    if (cardFlips[index] || selectedIndexes.length == 2) return;

    setState(() {
      cardFlips[index] = true;
      selectedIndexes.add(index);
      moves++;
    });

    if (selectedIndexes.length == 2) {
      _checkMatch();
    }
  }

  void _checkMatch() {
    int first = selectedIndexes[0];
    int second = selectedIndexes[1];

    if (gameCards[first] == gameCards[second]) {
      // Match trouvé!
      pairsFound++;
      selectedIndexes.clear();

      if (pairsFound == 8) {
        _gameWon();
      }
    } else {
      // Pas de match, retourner les cartes
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() {
            cardFlips[first] = false;
            cardFlips[second] = false;
            selectedIndexes.clear();
          });
        }
      });
    }
  }

  void _gameWon() {
    gameWon = true;

    // ÉCONOMIE RENTABLE:
    // Interstitiel: $0.01 revenue
    // Temps réduit à 90s, gains réduits
    // Temps bonus: 0.5 coin/sec (max ~45 coins si terminé rapidement)
    // Bonus coups: max 50 coins
    // Base: 50 coins
    // Total max: ~145 coins = $0.00725
    // Max doublé: 290 coins = $0.0145
    // Profit: $0.01 - $0.0145 = -$0.0045 (perte acceptable, limitée à 3/jour)

    int timeBonus = (timeLeft * 0.5).toInt(); // 0.5 coin par seconde
    int moveBonus = max(0, 50 - moves); // Bonus si peu de coups
    int totalPrize = 50 + timeBonus + moveBonus;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.green.shade900,
        title:
            const Text('🎉 Victoire!', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/ptitcoin.png', width: 80, height: 80),
            const SizedBox(height: 10),
            Text(
              '+$totalPrize PtitCoins',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Temps: ${90 - timeLeft}s\nCoups: $moves',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          if (_adLoaded)
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await AdService.showRewardedAd(_rewardedAd, (amount) {
                  widget.onWin(totalPrize * 2);
                  Navigator.pop(context, totalPrize * 2);
                });
              },
              icon: const Icon(Icons.movie),
              label: const Text('Doubler x2 (pub)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.yellow.shade700,
                foregroundColor: Colors.black,
              ),
            ),
          TextButton(
            onPressed: () {
              widget.onWin(totalPrize);
              Navigator.pop(context);
              Navigator.pop(context, totalPrize);
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Prendre ', style: TextStyle(color: Colors.white)),
                Image.asset('assets/images/ptitcoin.png',
                    width: 16, height: 16),
                Text(' $totalPrize PtitCoins',
                    style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _gameLost() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.red.shade900,
        title: const Text('😢 PERDU!', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.timer_off, size: 80, color: Colors.white),
            const SizedBox(height: 10),
            Text(
              'Temps écoulé!\nPaires trouvées: $pairsFound/8',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🧠 Memory Game'),
        backgroundColor: Colors.purple.shade900,
      ),
      body: AppBackground(
        child: SafeArea(
          child: gameReady ? _buildGameView() : _buildStartView(),
        ),
      ),
    );
  }

  Widget _buildStartView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.psychology, size: 100, color: Colors.white),
          const SizedBox(height: 20),
          const Text(
            '🧠 Memory Game',
            style: TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          FutureBuilder<int>(
            future: GameLimitsService.getMemoryPlaysLeft(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              return Text(
                '${snapshot.data} parties restantes',
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              );
            },
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Trouve toutes les paires!\n\n'
              '90 secondes • 8 paires\n'
              'Gagne jusqu\'à 145 coins',
              style: TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: _interstitialLoaded ? _showAdThenStart : null,
            icon: const Icon(Icons.play_arrow),
            label: Text(_interstitialLoaded ? 'JOUER (pub)' : 'Chargement...'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
              textStyle:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatCard('⏱️ Temps', '$timeLeft s', Colors.orange),
              _buildStatCard('🎯 Coups', '$moves', Colors.blue),
              _buildStatCard('✅ Paires', '$pairsFound/8', Colors.green),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: 16,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => _onCardTap(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      color: cardFlips[index]
                          ? Colors.white
                          : Colors.purple.shade700,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 5,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: cardFlips[index]
                          ? Text(
                              gameCards[index],
                              style: const TextStyle(fontSize: 40),
                            )
                          : const Icon(
                              Icons.question_mark,
                              color: Colors.white,
                              size: 40,
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
