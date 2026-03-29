import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:async';
import '../widgets/app_background.dart';
import '../services/ad_service.dart';
import '../services/game_limits_service.dart';

class ClickerGame extends StatefulWidget {
  final Function(int) onWin;

  const ClickerGame({super.key, required this.onWin});

  @override
  State<ClickerGame> createState() => _ClickerGameState();
}

class _ClickerGameState extends State<ClickerGame>
    with SingleTickerProviderStateMixin {
  int clicks = 0;
  int timeLeft = 30; // RÉDUIT À 30 SECONDES
  bool gameActive = false;
  bool gameStarted = false;
  Timer? gameTimer;
  RewardedAd? _rewardedAd;
  bool _adLoaded = false;
  InterstitialAd? _interstitialAd;
  bool _interstitialLoaded = false;
  late AnimationController _scaleController;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _checkLimitAndLoadAd();
    _loadRewardedAd();
  }

  Future<void> _checkLimitAndLoadAd() async {
    final canPlay = await GameLimitsService.canPlayClicker();
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
      adUnitId: 'ca-app-pub-8016803262695056/6760375035',
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

  void _showLimitReached() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('❌ Limite atteinte'),
        content: Text(
            'Tu as utilisé toutes tes 3 parties aujourd\'hui!\nReviens demain! ⏰'),
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

  void _showAdThenStart() {
    if (!_interstitialLoaded) {
      _startGame();
      GameLimitsService.recordClickerPlay();
      return;
    }

    _interstitialAd?.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _startGame();
        GameLimitsService.recordClickerPlay();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _startGame();
        GameLimitsService.recordClickerPlay();
      },
    );
    _interstitialAd?.show();
  }

  Future<void> _loadRewardedAd() async {
    _rewardedAd = await AdService.loadRewardedAd(
        'ca-app-pub-8016803262695056/3475736140');
    setState(() => _adLoaded = _rewardedAd != null);
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    _scaleController.dispose();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    super.dispose();
  }

  void _startGame() {
    setState(() {
      gameActive = true;
      gameStarted = true;
      clicks = 0;
      timeLeft = 30; // 30 secondes
    });

    gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (timeLeft > 0) {
        setState(() => timeLeft--);
      } else {
        _endGame();
      }
    });
  }

  void _onCoinTap() {
    if (!gameActive) return;

    setState(() {
      clicks++;
    });

    _scaleController.forward().then((_) {
      _scaleController.reverse();
    });
  }

  void _endGame() {
    gameTimer?.cancel();
    setState(() => gameActive = false);

    // CALCUL LIMITÉ: 1 click = 0.5 coin, max ~150 coins en 30sec
    // Revenue interstitiel = $0.01
    // Max coins doublé = 300 = $0.015
    // Profit: $0.01 - $0.015 = -$0.005 (perte si doublé) MAIS limite de 3 parties/jour donc perte max = -$0.015/jour acceptable
    final int finalCoins = (clicks * 0.5).toInt(); // 0.5 coin par click
    final int maxCoins = 150; // Plafond absolu
    final int earnedCoins = finalCoins > maxCoins ? maxCoins : finalCoins;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.orange.shade900,
        title: const Text('⏱️ Temps écoulé!',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/ptitcoin.png', width: 80, height: 80),
            const SizedBox(height: 10),
            Text(
              '+$earnedCoins PtitCoins',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Clicks: $clicks${finalCoins > maxCoins ? "\n(Max atteint!)" : ""}',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (_adLoaded)
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await AdService.showRewardedAd(_rewardedAd!, (amount) {
                    widget.onWin(earnedCoins * 2);
                    Navigator.pop(context, earnedCoins * 2);
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
              widget.onWin(earnedCoins);
              Navigator.pop(context);
              Navigator.pop(context, earnedCoins);
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Prendre ', style: TextStyle(color: Colors.white)),
                Image.asset('assets/images/ptitcoin.png',
                    width: 16, height: 16),
                Text(' $earnedCoins PtitCoins',
                    style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('💰 Clicker Game'),
        backgroundColor: Colors.purple.shade900,
      ),
      body: AppBackground(
        child: SafeArea(
          child: gameStarted ? _buildGameView() : _buildStartView(),
        ),
      ),
    );
  }

  Widget _buildStartView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.touch_app, size: 100, color: Colors.white),
          const SizedBox(height: 20),
          const Text(
            '💰 Clicker Game',
            style: TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          FutureBuilder<int>(
            future: GameLimitsService.getClickerPlaysLeft(),
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
              'Clique aussi vite que possible!\n\n'
              '30 secondes • 0.5 coin par click\n'
              'Max 150 coins',
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
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.black.withOpacity(0.3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat('⏱️', '$timeLeft s'),
              _buildStat('👆', '$clicks clicks'),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: GestureDetector(
              onTap: _onCoinTap,
              child: AnimatedBuilder(
                animation: _scaleController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.0 + (_scaleController.value * 0.2),
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.yellow.withOpacity(0.5),
                            blurRadius: 30,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: Image.asset('assets/images/ptitcoin.png'),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Text(
            'Clique sur la pièce!\n${(clicks * 0.5).toInt()} PtitCoins',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildStat(String emoji, String value) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
