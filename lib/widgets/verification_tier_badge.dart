import 'package:flutter/material.dart';

class VerificationTierBadge extends StatelessWidget {
  final String tier;

  const VerificationTierBadge({super.key, required this.tier});

  @override
  Widget build(BuildContext context) {
    switch (tier) {
      case 'verified':
        return _buildBadge("Verified Worker", Colors.amber);
      case 'police_verified':
        return _buildBadge("Trusted Pro ⭐", Colors.green);
      default:
        return _buildBadge("Not Verified", Colors.red);
    }
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
