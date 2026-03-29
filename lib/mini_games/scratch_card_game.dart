import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:math';
import '../services/ad_service.dart';
import '../services/game_limits_service.dart';

class ScratchCardGame extends StatefulWidget {
  final Function(int) onWin;

  const ScratchCardGame({super.key, required this.onWin});

  @override
  State<ScratchCardGame> createState() => _ScratchCardGameState();
}

class _ScratchCardGameState extends State<ScratchCardGame> {
  List<bool> scratched = List.filled(9, false);
  int? prize;
  bool gameOver = false;
  bool gameStarted = false;
  RewardedAd? _rewardedAd;
  bool _adLoaded = false;
  InterstitialAd? _interstitialAd;
  bool _interstitialLoaded = false;

  @override
  void initState() {
    super.initState();
    _checkLimitAndLoadAd();
    _loadRewardedAd();
  }

  Future<void> _checkLimitAndLoadAd() async {
    final canPlay = await GameLimitsService.canPlayScratchCard();
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
      adUnitId:
          'ca-app-pub-8016803262695056/1421268503', // Scratch Card Interstitial
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialLoaded = true;
          setState(() {});
        },
        onAdFailedToLoad: (error) {
          print('Interstitiel non chargé: $error');
        },
      ),
    );
  }

  Future<void> _loadRewardedAd() async {
    _rewardedAd = await AdService.loadRewardedAd(
        'ca-app-pub-8016803262695056/2821130027');
    setState(() => _adLoaded = _rewardedAd != null);
  }

  void _showLimitReached() async {
    final playsLeft = await GameLimitsService.getScratchPlaysLeft();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('❌ Limite atteinte'),
        content: Text(
            'Tu as utilisé toutes tes $playsLeft parties aujourd\'hui!\nReviens demain! ⏰'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Dialog
              Navigator.pop(context); // Game
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _startGame() {
    if (!_interstitialLoaded) {
      _generatePrize();
      setState(() => gameStarted = true);
      GameLimitsService.recordScratchPlay();
      return;
    }

    _interstitialAd?.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _generatePrize();
        setState(() => gameStarted = true);
        GameLimitsService.recordScratchPlay();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _generatePrize();
        setState(() => gameStarted = true);
        GameLimitsService.recordScratchPlay();
      },
    );
    _interstitialAd?.show();
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }

  void _generatePrize() {
    final random = Random();
    final roll = random.nextInt(100);

    // RATIO PERDANT/GAGNANT POUR RENTABILITÉ
    // Interstitiel = $0.01 revenue
    // 60% PERDANT (0 coins) = $0 cost
    // 40% GAGNANT:
    //   - 25% : 10-30 coins (moyenne 20)
    //   - 10% : 30-60 coins (moyenne 45)
    //   - 5% : 60-120 coins (moyenne 90)
    // Gain moyen: 0.40 × ((0.25×20) + (0.10×45) + (0.05×90)) = 0.40 × 13 = 5.2 coins = $0.00026
    // Profit: $0.01 - $0.00026 = +$0.00974 ✅

    if (roll < 60) {
      prize = 0; // PERDANT (60%)
    } else if (roll < 85) {
      prize = 10 + random.nextInt(20); // 10-30 (25%)
    } else if (roll < 95) {
      prize = 30 + random.nextInt(30); // 30-60 (10%)
    } else {
      prize = 60 + random.nextInt(60); // 60-120 (5%)
    }
  }

  void _scratch(int index) {
    if (!gameStarted) return; // Attendre la pub
    if (gameOver || scratched[index]) return;

    setState(() {
      scratched[index] = true;
    });

    // Si tout est gratté
    if (scratched.every((s) => s)) {
      setState(() {
        gameOver = true;
      });

      Future.delayed(const Duration(milliseconds: 500), () {
        if (prize! > 0) {
          // GAGNANT
          _showWinDialog();
        } else {
          // PERDANT
          _showLoseDialog();
        }
      });
    }
  }

  void _showWinDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🎉 SUPER DÉCOUVERTE!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/ptitcoin.png', width: 80, height: 80),
            const SizedBox(height: 10),
            Text(
              'Tu as gagné $prize PtitCoins!',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (_adLoaded)
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await AdService.showRewardedAd(_rewardedAd!, (amount) {
                    widget.onWin(prize! * 2);
                    Navigator.pop(context, prize! * 2);
                  });
                  _rewardedAd = null;
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('🎬 Doubler x2 (pub)'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              widget.onWin(prize!);
              Navigator.pop(context);
              Navigator.pop(context, prize);
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Prendre ', style: TextStyle(color: Colors.white)),
                Image.asset('assets/images/ptitcoin.png',
                    width: 16, height: 16),
                Text(' $prize PtitCoins',
                    style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLoseDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🔍 RIEN TROUVÉ!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 80, color: Colors.orange),
            const SizedBox(height: 10),
            const Text(
              'Continue ta recherche!',
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, 0);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎮 Jeu Découverte'),
        backgroundColor: Colors.purple,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.purple.shade900, Colors.black],
          ),
        ),
        child: Center(
          child: !gameStarted
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.explore, size: 100, color: Colors.white),
                    const SizedBox(height: 20),
                    const Text(
                      'Jeu Découverte',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    FutureBuilder<int>(
                      future: GameLimitsService.getScratchPlaysLeft(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox();
                        return Text(
                          '${snapshot.data} parties restantes',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 16),
                        );
                      },
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton.icon(
                      onPressed: _interstitialLoaded ? _startGame : null,
                      icon: const Icon(Icons.search),
                      label: Text(_interstitialLoaded
                          ? 'CHERCHER (pub)'
                          : 'Chargement...'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40, vertical: 15),
                        textStyle: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        '60% rien\n40% de chances de trouver 10-120 PtitCoins!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '🔎 Explore toutes les zones!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: 300,
                      height: 300,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.purple.withOpacity(0.5),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 5,
                          mainAxisSpacing: 5,
                        ),
                        itemCount: 9,
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: () => _scratch(index),
                            child: Container(
                              decoration: BoxDecoration(
                                color: scratched[index]
                                    ? (prize! > 0
                                        ? Colors.green.shade100
                                        : Colors.red.shade100)
                                    : Colors.grey.shade400,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: scratched[index]
                                    ? (prize! > 0
                                        ? Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Image.asset(
                                                'assets/images/ptitcoin.png',
                                                width: 40,
                                                height: 40,
                                              ),
                                              Text(
                                                '${prize! ~/ 9}',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.green,
                                                ),
                                              ),
                                            ],
                                          )
                                        : const Icon(Icons.close,
                                            size: 50, color: Colors.red))
                                    : const Icon(
                                        Icons.help_outline,
                                        size: 40,
                                        color: Colors.white,
                                      ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
