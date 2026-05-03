import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_spacing.dart';
import '../core/models/user_profile.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../widgets/app_logo.dart';
import 'login_screen.dart';

/// Shown after permissions, before login/signup.
/// User picks "I need help" (elder) or "I'm a caregiver".
class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  Future<void> _selectRole(BuildContext context, UserRole role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', role.name);
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, animation, __) => const LoginScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.xl),
              const AppLogo(iconSize: 32),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                'How will you use\nEverWith?',
                textAlign: TextAlign.center,
                style: AppTextStyles.heading,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Choose your role to get started',
                textAlign: TextAlign.center,
                style: AppTextStyles.body,
              ),
              const Spacer(),
              _RoleCard(
                icon: Icons.person_rounded,
                label: 'I need help',
                description: 'I want a voice companion\nto manage my daily care',
                color: AppColors.primaryBlue,
                onTap: () => _selectRole(context, UserRole.elder),
              ),
              const SizedBox(height: AppSpacing.lg),
              _RoleCard(
                icon: Icons.health_and_safety_rounded,
                label: "I'm a caregiver",
                description: 'I want to monitor and\nsupport a loved one',
                color: AppColors.successGreen,
                onTap: () => _selectRole(context, UserRole.caregiver),
              ),
              const Spacer(),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _RoleCard
// ─────────────────────────────────────────────────────────────────────────────

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xl,
          ),
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: color.withAlpha(60), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withAlpha(30),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTextStyles.heading.copyWith(fontSize: 20),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(description, style: AppTextStyles.body),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 18,
                color: color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
