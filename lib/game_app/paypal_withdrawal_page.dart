import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/user_data_service.dart';

class PayPalWithdrawalPage extends StatefulWidget {
  final double availableCash;
  final int currentPoints;
  final Function(String type, double amount, String email) onConfirm;

  const PayPalWithdrawalPage({
    super.key,
    required this.availableCash,
    required this.currentPoints,
    required this.onConfirm,
  });

  @override
  State<PayPalWithdrawalPage> createState() => _PayPalWithdrawalPageState();
}

class _PayPalWithdrawalPageState extends State<PayPalWithdrawalPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  static const double minWithdrawal = 10.0;

  @override
  void initState() {
    super.initState();
    // Pré-remplir avec l'email de l'utilisateur connecté
    _emailController.text = FirebaseAuth.instance.currentUser?.email ?? '';
    // Pré-remplir avec le montant maximum disponible
    _amountController.text = widget.availableCash.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _sendEmailNotification(String userEmail, double amount) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final userName =
        currentUser?.displayName ?? currentUser?.email ?? 'Utilisateur';
    final userId = currentUser?.uid ?? 'N/A';

    final subject = Uri.encodeComponent('RETRAIT PAYPAL - Le Ptit Cash');
    final body = Uri.encodeComponent('NOUVELLE DEMANDE DE RETRAIT PAYPAL\n'
        '\n'
        '═══════════════════════════════════\n'
        'INFORMATIONS CLIENT\n'
        '═══════════════════════════════════\n'
        'Nom/Email utilisateur: $userName\n'
        'User ID Firebase: $userId\n'
        'Email PayPal du client: $userEmail\n'
        '\n'
        '═══════════════════════════════════\n'
        'DÉTAILS DU RETRAIT\n'
        '═══════════════════════════════════\n'
        'Type: PayPal\n'
        'Montant: $amount \$ CAD\n'
        'Date de demande: ${DateTime.now()}\n'
        '\n'
        '═══════════════════════════════════\n'
        'ACTION REQUISE\n'
        '═══════════════════════════════════\n'
        '1. Ouvrez PayPal\n'
        '2. Envoyez $amount \$ CAD\n'
        '3. Depuis: vincent.corbeil.app@gmail.com\n'
        '4. Vers: $userEmail\n'
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
    final amount = double.tryParse(_amountController.text) ?? 0;

    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email PayPal invalide'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (amount < minWithdrawal) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Montant minimum: ${minWithdrawal.toStringAsFixed(0)}\$'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (amount > widget.availableCash) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solde insuffisant'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Envoyer l'email de notification
    await _sendEmailNotification(email, amount);

    // Enregistrer dans Firestore
    final pointsDeducted = (amount * 20000).toInt();
    await UserDataService.recordRedemption(
      type: 'Badge Premium',
      amount: amount,
      pointsDeducted: pointsDeducted,
      recipientEmail: email,
    );

    widget.onConfirm('paypal', amount, email);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Retrait PayPal'),
        backgroundColor: const Color(0xFF0070BA), // Couleur PayPal
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // PayPal Logo
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: const Color(0xFF0070BA),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.account_balance_wallet,
                    color: Colors.white,
                    size: 60,
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'PayPal',
                    style: TextStyle(
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

            // Email Field
            const Text(
              'Email PayPal',
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
                hintText: 'votre-email@paypal.com',
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
            const SizedBox(height: 20),

            // Amount Field
            const Text(
              'Montant à retirer',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _amountController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: '10.00',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.attach_money, color: Colors.green),
                suffixText: 'CAD',
                suffixStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.grey.shade900,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
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
                  const Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'Informations PayPal',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildInfoRow('• Minimum: 10\$ CAD'),
                  _buildInfoRow('• Délai: 24-48 heures'),
                  _buildInfoRow('• Frais: 0\$ (gratuit)'),
                  _buildInfoRow('• L\'argent sera envoyé directement'),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Confirm Button
            ElevatedButton(
              onPressed: _confirmWithdrawal,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0070BA),
                padding: const EdgeInsets.all(18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Confirmer le retrait',
                style: TextStyle(
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
