import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBanner();
  }

  void _loadBanner() {
    _bannerAd = AdService.loadBannerAd(
      AdService.bannerLeaderboardId,
      (loaded) => setState(() => _isBannerLoaded = loaded),
    );
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🏆 Classement Hebdomadaire'),
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
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .orderBy('totalPoints', descending: true)
              .limit(100)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.orange),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Text(
                  'Aucun joueur pour le moment',
                  style: TextStyle(color: Colors.white70),
                ),
              );
            }

            final users = snapshot.data!.docs;

            return Column(
              children: [
                // Top 3 Podium
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.orange.shade900, Colors.black],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (users.length > 1)
                        _buildPodium(
                            users[1].data() as Map<String, dynamic>, 2, '🥈'),
                      if (users.isNotEmpty)
                        _buildPodium(
                            users[0].data() as Map<String, dynamic>, 1, '🥇'),
                      if (users.length > 2)
                        _buildPodium(
                            users[2].data() as Map<String, dynamic>, 3, '🥉'),
                    ],
                  ),
                ),

                // Liste des autres
                Expanded(
                  child: ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final userData =
                          users[index].data() as Map<String, dynamic>;
                      final userId = users[index].id;
                      final isCurrentUser = userId == currentUser?.uid;

                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isCurrentUser
                              ? Colors.orange.withOpacity(0.3)
                              : Colors.grey.shade900,
                          borderRadius: BorderRadius.circular(10),
                          border: isCurrentUser
                              ? Border.all(color: Colors.orange, width: 2)
                              : null,
                        ),
                        child: ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _getRankColor(index + 1),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '#${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                userData['email']?.split('@')[0] ?? 'Joueur',
                                style: TextStyle(
                                  color: isCurrentUser
                                      ? Colors.orange
                                      : Colors.white,
                                  fontWeight: isCurrentUser
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              if (isCurrentUser)
                                const Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: Text(
                                    '(Toi)',
                                    style: TextStyle(
                                      color: Colors.orange,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/images/ptitcoin.png',
                                width: 20,
                                height: 20,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '${userData['totalPoints'] ?? 0}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: _isBannerLoaded && _bannerAd != null
          ? SizedBox(
              height: 50,
              child: AdWidget(ad: _bannerAd!),
            )
          : null,
    );
  }

  Widget _buildPodium(Map<String, dynamic> userData, int rank, String medal) {
    final height = rank == 1 ? 120.0 : (rank == 2 ? 100.0 : 80.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          medal,
          style: const TextStyle(fontSize: 40),
        ),
        Container(
          width: 80,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: rank == 1
                  ? [Colors.amber, Colors.orange]
                  : rank == 2
                      ? [Colors.grey.shade400, Colors.grey.shade600]
                      : [Colors.brown.shade300, Colors.brown.shade700],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                userData['email']?.split('@')[0] ?? 'Joueur',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 5),
              Text(
                '${userData['totalPoints'] ?? 0}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getRankColor(int rank) {
    if (rank <= 3) return Colors.orange;
    if (rank <= 10) return Colors.purple;
    if (rank <= 50) return Colors.blue;
    return Colors.grey;
  }
}
