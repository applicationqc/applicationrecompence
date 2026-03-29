import 'package:flutter/material.dart';

/// Widget de fond avec dégradé uniforme pour toute l'application
class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.purple.shade900,
            Colors.blue.shade900,
            Colors.black,
          ],
        ),
      ),
      child: child,
    );
  }
}

/// Thème global de l'application
class AppTheme {
  static const Color primaryColor = Color(0xFF6A1B9A); // Purple
  static const Color accentColor = Color(0xFF1565C0); // Blue
  static const Color backgroundColor = Colors.black;

  static final LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Colors.purple.shade900,
      Colors.blue.shade900,
      Colors.black,
    ],
  );
}
