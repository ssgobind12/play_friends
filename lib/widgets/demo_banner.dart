import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DemoBanner extends StatelessWidget {
  final String message;
  final IconData icon;

  const DemoBanner({
    super.key,
    this.message =
        'DEMO MODE - Simulated local play only. Online multiplayer is not connected.',
    this.icon = Icons.info_outline_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryPurple.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primaryPurple.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primaryPurpleLight),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
