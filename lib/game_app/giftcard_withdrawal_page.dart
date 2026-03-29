import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/user_data_service.dart';

class GiftCardWithdrawalPage extends StatefulWidget {
  final String type; // 'amazon', 'google_play', 'itunes'
  final double availableCash;
  final int currentPoints;
  final Function(String type, double amount, String email) onConfirm;

  const GiftCardWithdrawalPage({
    super.key,
    required this.type,
    required this.availableCash,
    required this.currentPoints,
    required this.onConfirm,
  });

  @override
  State<GiftCardWithdrawalPage> createState() => _GiftCardWithdrawalPageState();
}

class _GiftCardWithdrawalPageState extends State<GiftCardWithdrawalPage> {
  final TextEditingController _emailController = TextEditingController();
  double? _selectedAmount;
  final List<double> _predefinedAmounts = [10, 25, 50, 100];

  @override
  void initState() {
    super.initState();
    _emailController.text = FirebaseAuth.instance.currentUser?.email ?? '';
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String get _title {
    switch (widget.type) {
      case 'amazon':
        return 'Amazon';
      case 'google_play':
        return 'Google Play';
      case 'itunes':
        return 'iTunes / App Store';
      default:
        return 'Carte-cadeau';
    }
  }

  IconData get _icon {
    switch (widget.type) {
      case 'amazon':
        return Icons.card_giftcard;
      case 'google_play':
        return Icons.android;
      case 'itunes':
        return Icons.apple;
      default:
        return Icons.card_giftcard;
    }
  }

  Color get _color {
    switch (widget.type) {
      case 'amazon':
        return Colors.orange;
      case 'google_play':
        return Colors.green;
      case 'itunes':
        return Colors.black;
      default:
        return Colors.blue;
    }
  }

  Future<void> _sendEmailNotification(String userEmail, double amount) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final userName =
        currentUser?.displayName ?? currentUser?.email ?? 'Utilisateur';
    final userId = currentUser?.uid ?? 'N/A';

    final subject =
        Uri.encodeComponent('RETRAIT CARTE-CADEAU $_title - Le Ptit Cash');
    final body =
        Uri.encodeComponent('NOUVELLE DEMANDE DE RETRAIT CARTE-CADEAU\n'
            '\n'
            '═══════════════════════════════════\n'
            'INFORMATIONS CLIENT\n'
            '═══════════════════════════════════\n'
            'Nom/Email utilisateur: $userName\n'
            'User ID Firebase: $userId\n'
            'Email du client: $userEmail\n'
            '\n'
            '═══════════════════════════════════\n'
            'DÉTAILS DU RETRAIT\n'
            '═══════════════════════════════════\n'
            'Type: Carte-cadeau $_title\n'
            'Montant: $amount \$ CAD\n'
            'Date de demande: ${DateTime.now()}\n'
            '\n'
            '═══════════════════════════════════\n'
            'ACTION REQUISE\n'
            '═══════════════════════════════════\n'
            '1. Achetez une carte-cadeau $_title de $amount \$\n'
            '2. Envoyez le code par email à: $userEmail\n'
            '\n'
            'Merci!');

    final emailUri = Uri.parse(
        'mailto:vincent.corbeil.app@gmail.com?subject=$subject&body=$body');

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible d\'ouvrir l\'application email'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _confirmWithdrawal() async {
    final email = _emailController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email invalide'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedAmount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sélectionnez un montant'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedAmount! > widget.availableCash) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solde insuffisant'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Envoyer l'email de notification
    await _sendEmailNotification(email, _selectedAmount!);

    // Enregistrer dans Firestore
    final pointsDeducted = (_selectedAmount! * 20000).toInt();
    await UserDataService.recordRedemption(
      type: 'Récompense virtuelle $_title',
      amount: _selectedAmount!,
      pointsDeducted: pointsDeducted,
      recipientEmail: email,
    );

    widget.onConfirm(widget.type, _selectedAmount!, email);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Carte-cadeau $_title'),
        backgroundColor: _color,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: _color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Icon(
                    _icon,
                    color: Colors.white,
                    size: 60,
                  ),
                  const SizedBox(height: 15),
                  Text(
                    _title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Solde disponible: ${widget.availableCash.toStringAsFixed(2)} \$ CAD',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Amount Selection
            const Text(
              'Choisissez le montant',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 15),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _predefinedAmounts.map((amount) {
                final isAvailable = amount <= widget.availableCash;
                final isSelected = _selectedAmount == amount;
                return GestureDetector(
                  onTap: isAvailable
                      ? () {
                          setState(() {
                            _selectedAmount = amount;
                          });
                        }
                      : null,
                  child: Container(
                    width: (MediaQuery.of(context).size.width - 50) / 2,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _color
                          : (isAvailable
                              ? Colors.grey.shade900
                              : Colors.grey.shade800),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: isSelected
                            ? _color
                            : (isAvailable
                                ? _color.withOpacity(0.3)
                                : Colors.grey),
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${amount.toStringAsFixed(0)}\$',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isAvailable ? Colors.white : Colors.grey,
                          ),
                        ),
                        Text(
                          'CAD',
                          style: TextStyle(
                            fontSize: 12,
                            color: isAvailable ? Colors.white70 : Colors.grey,
                          ),
                        ),
                        if (!isAvailable)
                          const Text(
                            'Solde insuffisant',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.red,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 30),

            // Email Field
            const Text(
              'Email pour recevoir le code',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _emailController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'votre-email@exemple.com',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.email, color: Colors.blue),
                filled: true,
                fillColor: Colors.grey.shade900,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 30),

            // Info Box
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.blue.shade900.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade700),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info, color: Colors.blue, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'Infos Carte-cadeau $_title',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildInfoRow(
                      '• Montants disponibles: 10\$, 25\$, 50\$, 100\$'),
                  _buildInfoRow('• Délai: 24-48 heures'),
                  _buildInfoRow('• Frais: 0\$ (gratuit)'),
                  _buildInfoRow('• Code envoyé par email'),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Confirm Button
            ElevatedButton(
              onPressed: _selectedAmount != null ? _confirmWithdrawal : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _color,
                disabledBackgroundColor: Colors.grey.shade800,
                padding: const EdgeInsets.all(18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                _selectedAmount != null
                    ? 'Confirmer le retrait de ${_selectedAmount!.toStringAsFixed(0)}\$'
                    : 'Sélectionnez un montant',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, color: Colors.white70),
      ),
    );
  }
}
