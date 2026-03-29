import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:convert';
import 'paypal_withdrawal_page.dart';
import 'giftcard_withdrawal_page.dart';

class WithdrawalData {
  final String type; // 'paypal', 'amazon', 'google_play', 'itunes'
  final double amount;
  final String date;
  final String status; // 'pending', 'completed', 'rejected'

  WithdrawalData({
    required this.type,
    required this.amount,
    required this.date,
    required this.status,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'amount': amount,
      'date': date,
      'status': status,
    };
  }

  factory WithdrawalData.fromJson(Map<String, dynamic> json) {
    return WithdrawalData(
      type: json['type'],
      amount: json['amount']?.toDouble() ?? 0,
      date: json['date'],
      status: json['status'],
    );
  }
}

class WithdrawalScreen extends StatefulWidget {
  final int currentPoints;
  final Function(int) onWithdraw;

  const WithdrawalScreen({
    super.key,
    required this.currentPoints,
    required this.onWithdraw,
  });

  @override
  State<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends State<WithdrawalScreen> {
  List<WithdrawalData> withdrawals = [];
  BannerAd? _bannerAd;
  BannerAd? _topBannerAd;
  bool _isBannerReady = false;
  bool _isTopBannerReady = false;

  // Conversion: 200,000 points = 10$ CAD (20,000 points = 1$)
  static const int pointsPerDollar = 20000;
  static const double minWithdrawal = 10.0;
  final String _bannerUnitId = 'ca-app-pub-8016803262695056/8719667429';
  final String _topBannerUnitId = 'ca-app-pub-8016803262695056/8291775090';

  @override
  void initState() {
    super.initState();
    _loadWithdrawals();
    _chargerBannerAd();
    _chargerTopBannerAd();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _topBannerAd?.dispose();
    super.dispose();
  }

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
          print('Erreur chargement bannière withdrawal: $err');
        },
      ),
    )..load();
  }

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
          print('Erreur chargement bannière top withdrawal: $err');
        },
      ),
    )..load();
  }

  Future<void> _loadWithdrawals() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('redemptionHistory');
    if (data != null) {
      final List<dynamic> list = json.decode(data);
      setState(() {
        withdrawals = list.map((w) => WithdrawalData.fromJson(w)).toList();
      });
    }
  }

  Future<void> _saveWithdrawals() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'redemptionHistory',
      json.encode(withdrawals.map((w) => w.toJson()).toList()),
    );
  }

  double get availableCash => widget.currentPoints / pointsPerDollar;
  bool get canWithdraw => availableCash >= minWithdrawal;

  void _navigateToPayPal() async {
    if (!canWithdraw) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solde insuffisant pour débloquer cette récompense (minimum 200,000 points)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PayPalWithdrawalPage(
          availableCash: availableCash,
          currentPoints: widget.currentPoints,
          onConfirm: _processWithdrawal,
        ),
      ),
    );
  }

  void _navigateToGiftCard(String type) async {
    if (!canWithdraw) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solde insuffisant pour débloquer cette récompense (minimum 200,000 points)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GiftCardWithdrawalPage(
          type: type,
          availableCash: availableCash,
          currentPoints: widget.currentPoints,
          onConfirm: _processWithdrawal,
        ),
      ),
    );
  }

  void _showComingSoon(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🚧 Bientôt disponible'),
        content: Text(
          '$feature sera bientôt disponible!\n\nContinuez à accumuler des points pour débloquer ces récompenses prochainement.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _processWithdrawal(String type, double amount, String userEmail) {
    final pointsToDeduct = (amount * pointsPerDollar).toInt();

    setState(() {
      withdrawals.insert(
        0,
        WithdrawalData(
          type: type,
          amount: amount,
          date: DateTime.now().toString().substring(0, 16),
          status: 'pending',
        ),
      );
    });

    widget.onWithdraw(pointsToDeduct);
    _saveWithdrawals();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Retrait de ${amount.toStringAsFixed(2)}\$ en cours!\nVous recevrez votre paiement sous 24-48h.',
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎁 Échanger mes Points'),
        backgroundColor: Colors.purple.shade900,
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ), // Balance Card
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.green, Colors.teal],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.3),
                      blurRadius: 15,
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
                          '${widget.currentPoints.toStringAsFixed(0)}',
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
                      'Équivaut à ${availableCash.toStringAsFixed(2)}\$',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Withdrawal Options
              const Text(
                '🎁 Échangez vos points contre des récompenses virtuelles',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),

              _buildWithdrawalOption(
                'Badges Premium',
                'Débloquez des badges exclusifs',
                Icons.emoji_events,
                Colors.amber,
                () => _showComingSoon('Badges Premium'),
              ),
              const SizedBox(height: 10),
              _buildWithdrawalOption(
                'Avatars Personnalisés',
                'Débloquez des avatars uniques',
                Icons.face,
                Colors.purple,
                () => _showComingSoon('Avatars'),
              ),
              const SizedBox(height: 10),
              _buildWithdrawalOption(
                'Thèmes Colorés',
                'Personnalisez votre interface',
                Icons.palette,
                Colors.pink,
                () => _showComingSoon('Thèmes'),
              ),
              const SizedBox(height: 10),
              _buildWithdrawalOption(
                'Bonus de Points',
                'Multipliez vos gains quotidiens',
                Icons.add_box,
                Colors.green,
                () => _showComingSoon('Bonus'),
              ),

              const SizedBox(height: 30),

              // Info Box
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 30),
                    SizedBox(height: 10),
                    Text(
                      'ℹ️ Important',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Les récompenses sont virtuelles et à but de divertissement uniquement. Continuez à jouer pour débloquer plus de contenu!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black87),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Section discrète pour options de paiement (moins visible)
              ExpansionTile(
                title: const Text(
                  '💳 Options avancées',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                children: [
                  const Padding(
                    padding: EdgeInsets.all(10),
                    child: Text(
                      'Options de conversion (nécessite validation)',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.account_balance_wallet, size: 20),
                    title: const Text('PayPal', style: TextStyle(fontSize: 14)),
                    subtitle: const Text('Minimum: 200,000 points', style: TextStyle(fontSize: 11)),
                    onTap: () => _navigateToPayPal(),
                  ),
                  ListTile(
                    leading: const Icon(Icons.card_giftcard, size: 20),
                    title: const Text('Amazon', style: TextStyle(fontSize: 14)),
                    subtitle: const Text('Minimum: 200,000 points', style: TextStyle(fontSize: 11)),
                    onTap: () => _navigateToGiftCard('amazon'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.android, size: 20),
                    title: const Text('Google Play', style: TextStyle(fontSize: 14)),
                    subtitle: const Text('Minimum: 200,000 points', style: TextStyle(fontSize: 11)),
                    onTap: () => _navigateToGiftCard('google_play'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.apple, size: 20),
                    title: const Text('iTunes', style: TextStyle(fontSize: 14)),
                    subtitle: const Text('Minimum: 200,000 points', style: TextStyle(fontSize: 11)),
                    onTap: () => _navigateToGiftCard('itunes'),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // History
              if (withdrawals.isNotEmpty) ...[
                const Text(
                  '📜 Historique des échanges',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),
                ...withdrawals.map((w) => _buildHistoryItem(w)).toList(),
              ],

              // Banner Ad at bottom
              if (_isBannerReady && _bannerAd != null)
                Container(
                  margin: const EdgeInsets.only(top: 20),
                  height: _bannerAd!.size.height.toDouble(),
                  width: double.infinity,
                  child: AdWidget(ad: _bannerAd!),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWithdrawalOption(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap:
          onTap, // Toujours actif maintenant, la vérification se fait dans la navigation
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: color,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(WithdrawalData withdrawal) {
    Color statusColor = withdrawal.status == 'completed'
        ? Colors.green
        : withdrawal.status == 'pending'
            ? Colors.orange
            : Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(
            withdrawal.status == 'completed'
                ? Icons.check_circle
                : withdrawal.status == 'pending'
                    ? Icons.access_time
                    : Icons.cancel,
            color: statusColor,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${withdrawal.amount.toStringAsFixed(2)}\$ CAD',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${withdrawal.type.toUpperCase()} • ${withdrawal.date}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              withdrawal.status == 'completed'
                  ? 'Complété'
                  : withdrawal.status == 'pending'
                      ? 'En cours'
                      : 'Rejeté',
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
