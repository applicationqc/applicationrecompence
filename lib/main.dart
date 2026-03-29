import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bitlabs/bitlabs.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'game_app/withdrawal_screen.dart';
import 'game_app/modern_home_screen.dart';
import 'auth_screen.dart';
import 'services/user_data_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialisation Firebase
  await Firebase.initializeApp();

  MobileAds.instance.initialize(); // Initialisation des pubs

  // Initialiser les notifications en arrière-plan (non bloquant)
  NotificationService.initialize().catchError((e) {
    print('❌ Erreur notifications: $e');
  });

  // BitLabs sera initialisé après login avec l'UID Firebase

  runApp(const MonJeuPayant());
}

class MonJeuPayant extends StatelessWidget {
  const MonJeuPayant({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Si le chargement prend plus de temps, on affiche quand même l'écran
          // Vérifier si on a des données OU si on attend depuis trop longtemps

          if (snapshot.hasData) {
            // Utilisateur connecté - Nouvelle interface moderne
            return const MainAppWrapper();
          } else if (snapshot.hasError) {
            // Erreur Firebase - montrer l'écran d'authentification
            print('❌ Erreur Firebase Auth: ${snapshot.error}');
            return const AuthScreen();
          } else if (snapshot.connectionState == ConnectionState.active ||
              snapshot.connectionState == ConnectionState.done) {
            // Pas d'utilisateur connecté
            return const AuthScreen();
          } else {
            // Chargement initial
            return const Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: CircularProgressIndicator(color: Colors.green),
              ),
            );
          }
        },
      ),
    );
  }
}

class PageJeu extends StatefulWidget {
  const PageJeu({super.key});

  @override
  State<PageJeu> createState() => _PageJeuState();
}

class _PageJeuState extends State<PageJeu> {
  int _score = 0;
  double _cashEarned = 0.0; // Points de jeu accumulés
  BannerAd? _bannerAd;
  BannerAd? _topBannerAd;
  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;
  bool _isBannerReady = false;
  bool _isTopBannerReady = false;

  // Limites quotidiennes
  int _videosWatchedToday = 0;
  int _surveysCompletedToday = 0;
  String _lastResetDate = '';

  static const int maxVideosPerDay = 40;
  static const int maxSurveysPerDay = 5;

  // Vrais ID AdMob pour Le P'tit Cash
  final String _bannerUnitId =
      'ca-app-pub-8016803262695056/1130991445'; // Bannière bas
  final String _topBannerUnitId =
      'ca-app-pub-8016803262695056/9692007745'; // Bannière haut
  final String _rewardUnitId =
      'ca-app-pub-8016803262695056/7959273615'; // Vidéo récompensée
  final String _interstitialUnitId =
      'ca-app-pub-8016803262695056/3621423411'; // Interstitiel

  // Système ajusté: Réduction des récompenses
  // 1 vidéo pub vous rapporte ~0.01$ → joueur reçoit moins
  // Réduit d'au moins 25% pour équilibrer l'économie du jeu
  // 20,000 points = 1$ CAD pour le joueur
  static const int pointsPerVideo = 75;
  static const int pointsPerSurvey = 1875; // Sondage vaut 25 vidéos

  @override
  void initState() {
    super.initState();
    _initBitLabs();
    _loadScore();
    _chargerBannerAd();
    _chargerTopBannerAd();
    _chargerRewardedAd();
    _chargerInterstitielAd();
  }

  // Initialiser BitLabs avec l'UID Firebase de l'utilisateur
  Future<void> _initBitLabs() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        BitLabs.instance.init('4040d4a9-1c20-423c-9f9a-f849f98e8ad2', user.uid);
        print('🎯 BitLabs initialisé avec UID: ${user.uid}');
      } catch (e) {
        print('❌ Erreur init BitLabs: $e');
      }
    }
  }

  Future<void> _loadScore() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _score = prefs.getInt('gameScore') ?? 0;
      _cashEarned = prefs.getDouble('cashEarned') ?? 0.0;
      _videosWatchedToday = prefs.getInt('videosToday') ?? 0;
      _surveysCompletedToday = prefs.getInt('surveysToday') ?? 0;
      _lastResetDate = prefs.getString('lastResetDate') ?? '';
    });
    _checkAndResetDaily();

    // Initialiser ou synchroniser avec Firestore
    await UserDataService.initializeUserData();
    await UserDataService.syncLocalData(
      localPoints: _score,
      localVideos: _videosWatchedToday,
      localSurveys: _surveysCompletedToday,
    );
  }

  Future<void> _saveScore() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('gameScore', _score);
    await prefs.setDouble('cashEarned', _cashEarned);
    await prefs.setInt('videosToday', _videosWatchedToday);
    await prefs.setInt('surveysToday', _surveysCompletedToday);
    await prefs.setString('lastResetDate', _lastResetDate);
  }

  void _checkAndResetDaily() {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (_lastResetDate != today) {
      setState(() {
        _videosWatchedToday = 0;
        _surveysCompletedToday = 0;
        _lastResetDate = today;
      });
      _saveScore();
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _topBannerAd?.dispose();
    _rewardedAd?.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }

  // 1. Charger la Bannière (Pub en bas)
  void _chargerBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: _bannerUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            _isBannerReady = true;
          });
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          print('Erreur chargement bannière: $err');
        },
      ),
    )..load();
  }

  // 1b. Charger la Bannière du haut
  void _chargerTopBannerAd() {
    _topBannerAd = BannerAd(
      adUnitId: _topBannerUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            _isTopBannerReady = true;
          });
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          print('Erreur chargement bannière du haut: $err');
        },
      ),
    )..load();
  }

  // 2. Charger la Vidéo Récompensée (Très payant)
  void _chargerRewardedAd() {
    RewardedAd.load(
      adUnitId: _rewardUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          print('✅ Vidéo récompensée chargée avec succès!');
        },
        onAdFailedToLoad: (LoadAdError err) {
          print('❌ Erreur chargement vidéo: $err');
          _rewardedAd = null;
        },
      ),
    );
  }

  // 2b. Charger la Vidéo Interstitielle
  void _chargerInterstitielAd() {
    InterstitialAd.load(
      adUnitId: _interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialAd!.setImmersiveMode(true);
        },
        onAdFailedToLoad: (LoadAdError err) {
          print('Erreur chargement interstitiel: $err');
          _interstitialAd = null;
        },
      ),
    );
  }

  // 3. Montrer la vidéo et donner une récompense
  void _montrerVideo() {
    print('🎬 Tentative d\'affichage vidéo...');
    _checkAndResetDaily();

    if (_videosWatchedToday >= maxVideosPerDay) {
      print(
          '⚠️ Limite quotidienne atteinte: $_videosWatchedToday/$maxVideosPerDay');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Limite quotidienne atteinte! Revenez demain (${maxVideosPerDay - _videosWatchedToday} vidéos restantes).'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_rewardedAd != null) {
      print('✅ Vidéo disponible, affichage...');
      _rewardedAd!.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          print('💰 Récompense gagnée! Points: $pointsPerVideo');
          // L'utilisateur a regardé la pub, on le paie en points
          setState(() {
            _score += pointsPerVideo; // 100 points
            _cashEarned += 0.015; // Simulation: 0.015$ par vidéo pour le joueur
            _videosWatchedToday++;
          });
          print(
              '📊 Nouveau score: $_score, Vidéos aujourd\'hui: $_videosWatchedToday');
          _saveScore();

          // Enregistrer dans Firestore
          print('☁️ Enregistrement dans Firestore...');
          UserDataService.recordVideoWatched(pointsPerVideo).then((_) {
            print('✅ Firestore enregistré avec succès!');
          }).catchError((error) {
            print('❌ Erreur Firestore vidéo: $error');
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Image.asset('assets/images/ptitcoin.png',
                      width: 24, height: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '+$pointsPerVideo PtitCoins gagnés! 💰\n${maxVideosPerDay - _videosWatchedToday} vidéos restantes aujourd\'hui',
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );

          // Afficher l'interstitiel après la récompense
          if (_interstitialAd != null) {
            print('📺 Affichage interstitiel...');
            _interstitialAd!.show();
            _interstitialAd!.fullScreenContentCallback =
                FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
                _chargerInterstitielAd(); // Recharger pour la prochaine fois
              },
              onAdFailedToShowFullScreenContent: (ad, err) {
                ad.dispose();
                _chargerInterstitielAd();
              },
            );
          }

          // Recharger une nouvelle pub pour la prochaine fois
          print('🔄 Rechargement de la prochaine vidéo...');
          _chargerRewardedAd();
        },
      );
    } else {
      print('❌ Vidéo pas prête (_rewardedAd est null)');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vidéo pas encore chargée, réessayez...')),
      );
    }
  }

  // 4. Système de sondage avec BitLabs
  void _ouvrirSondage() async {
    _checkAndResetDaily();

    if (_surveysCompletedToday >= maxSurveysPerDay) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Limite quotidienne de sondages atteinte! Revenez demain (${maxSurveysPerDay - _surveysCompletedToday} sondages restants).'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Configurer les callbacks BitLabs
      BitLabs.instance.setOnReward((reward) {
        // L'utilisateur a complété un sondage et reçoit une récompense
        setState(() {
          _score += pointsPerSurvey;
          _cashEarned += 0.375; // 15% de ~2.50$
          _surveysCompletedToday++;
        });
        _saveScore();

        // Enregistrer dans Firestore
        UserDataService.recordSurveyCompleted(pointsPerSurvey)
            .catchError((error) {
          print('Erreur Firestore sondage: $error');
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Image.asset('assets/images/ptitcoin.png',
                    width: 24, height: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '+$pointsPerSurvey PtitCoins gagnés! 🎉\n${maxSurveysPerDay - _surveysCompletedToday} sondages restants aujourd\'hui',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
          ),
        );
      });

      // Lancer l'interface BitLabs
      BitLabs.instance.launchOfferWall(context);
    } catch (e) {
      print('Erreur BitLabs: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Erreur lors du chargement des sondages. Réessayez plus tard.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    double cashAvailable = _score / 20000.0; // 20,000 points = 1$ CAD

    return WillPopScope(
      onWillPop: () async {
        // Permettre le retour en arrière
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.purple.shade900,
          elevation: 0,
          title: Row(
            children: [
              const Icon(Icons.person, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  FirebaseAuth.instance.currentUser?.email ?? 'Utilisateur',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.red),
              tooltip: 'Déconnexion',
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
              },
            ),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.purple.shade900,
                Colors.blue.shade900,
                Colors.black
              ],
            ),
          ),
          child: Stack(
            children: [
              SingleChildScrollView(
                child: Column(
                  children: [
                    // Banner Ad at top
                    if (_isTopBannerReady && _topBannerAd != null)
                      Container(
                        margin: const EdgeInsets.only(top: 10),
                        height: _topBannerAd!.size.height.toDouble(),
                        width: double.infinity,
                        child: AdWidget(ad: _topBannerAd!),
                      ),
                    // Splash image coloré en haut
                  Container(
                    margin: const EdgeInsets.all(20),
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
                  // Cash Display
                  Container(
                    margin: const EdgeInsets.all(20),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.green, Colors.teal],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          '🎮 Mes PtitCoins',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/images/ptitcoin.png',
                              width: 48,
                              height: 48,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '$_score',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Équivaut à ${cashAvailable.toStringAsFixed(2)}\$',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Section Monétisation
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/ptitcoin.png',
                        width: 20,
                        height: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "Jouer et gagner des PtitCoins :",
                        style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Compteurs quotidiens
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.video_library,
                                size: 16, color: Colors.green),
                            const SizedBox(width: 5),
                            Text(
                              '$_videosWatchedToday/$maxVideosPerDay',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.assignment,
                                size: 16, color: Colors.orange),
                            const SizedBox(width: 5),
                            Text(
                              '$_surveysCompletedToday/$maxSurveysPerDay',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.video_library),
                        label: const Text("Vidéo (+$pointsPerVideo)"),
                        onPressed: _videosWatchedToday < maxVideosPerDay
                            ? _montrerVideo
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          disabledBackgroundColor: Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.assignment),
                        label: const Text("Sondage (+$pointsPerSurvey)"),
                        onPressed: _surveysCompletedToday < maxSurveysPerDay
                            ? _ouvrirSondage
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          disabledBackgroundColor: Colors.grey,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Info Box
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.green, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '20,000 PtitCoins = 1\$ CAD\nRetirez à partir de 10\$ !',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Banner Ad at bottom
                  if (_isBannerReady && _bannerAd != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      height: _bannerAd!.size.height.toDouble(),
                      width: _bannerAd!.size.width.toDouble(),
                      child: AdWidget(ad: _bannerAd!),
                    ),

                  const SizedBox(height: 80), // Espace pour le bottom nav
                ],
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          mini: true,
          backgroundColor: Colors.green,
          child: const Icon(Icons.card_giftcard, size: 20),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WithdrawalScreen(
                  currentPoints: _score,
                  onWithdraw: (pointsDeducted) {
                    setState(() {
                      _score -= pointsDeducted;
                    });
                    _saveScore();
                  },
                ),
              ),
            );
          },
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
      ),
    );
  }
}

// Nouveau wrapper pour l'interface moderne
class MainAppWrapper extends StatefulWidget {
  const MainAppWrapper({super.key});

  @override
  State<MainAppWrapper> createState() => _MainAppWrapperState();
}

class _MainAppWrapperState extends State<MainAppWrapper> {
  int _currentIndex = 0;
  int _score = 0;

  @override
  void initState() {
    super.initState();
    _loadScore();
    _initBitLabs();
  }

  Future<void> _initBitLabs() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        BitLabs.instance.init('4040d4a9-1c20-423c-9f9a-f849f98e8ad2', user.uid);
        print('🎯 BitLabs initialisé avec UID: ${user.uid}');
      } catch (e) {
        print('❌ Erreur init BitLabs: $e');
      }
    }
  }

  Future<void> _loadScore() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _score = prefs.getInt('gameScore') ?? 0;
    });

    await UserDataService.initializeUserData();
  }

  Future<void> _saveScore() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('gameScore', _score);
  }

  void _updateScore(int points) {
    setState(() {
      _score += points;
    });
    _saveScore();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      ModernHomeScreen(score: _score, onScoreUpdate: _updateScore),
      const PageJeu(), // Ancien écran pour vidéos/sondages
      WithdrawalScreen(
        currentPoints: _score,
        onWithdraw: (pointsDeducted) {
          setState(() {
            _score -= pointsDeducted;
          });
          _saveScore();
        },
      ),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: Colors.black,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.play_circle),
            label: 'Jouer',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Boutique',
          ),
        ],
      ),
    );
  }
}
