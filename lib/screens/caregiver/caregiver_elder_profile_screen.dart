import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/models/user_profile.dart';
import '../../core/services/family_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Tab 3 — Elder's profile and emergency contacts.
class CaregiverElderProfileScreen extends StatefulWidget {
  const CaregiverElderProfileScreen({super.key, required this.elderUid});

  final String? elderUid;

  @override
  State<CaregiverElderProfileScreen> createState() =>
      _CaregiverElderProfileScreenState();
}

class _CaregiverElderProfileScreenState
    extends State<CaregiverElderProfileScreen> {
  UserProfile? _elderProfile;
  StreamSubscription<List<FamilyContact>>? _contactsSub;
  List<FamilyContact> _familyContacts = [];

  @override
  void initState() {
    super.initState();
    if (widget.elderUid != null) {
      _loadProfile();
      _contactsSub = FirestoreService.instance
          .streamFamilyContacts(widget.elderUid!)
          .listen((contacts) {
        if (mounted) setState(() => _familyContacts = contacts);
      });
    }
  }

  @override
  void dispose() {
    _contactsSub?.cancel();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile =
        await FirestoreService.instance.getUserProfile(widget.elderUid!);
    if (mounted) setState(() => _elderProfile = profile);
  }

  Future<void> _callNumber(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _messageNumber(String phone) async {
    final uri = Uri(scheme: 'sms', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.elderUid == null) {
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(
              'Link to an elder to view their profile.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body,
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        children: [
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Elder Profile',
            style: AppTextStyles.heading.copyWith(fontSize: 28),
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── Profile Card ─────────────────────────────────────────
          _ProfileCard(
            profile: _elderProfile,
            onCall: _elderProfile?.phone != null
                ? () => _callNumber(_elderProfile!.phone!)
                : null,
            onMessage: _elderProfile?.phone != null
                ? () => _messageNumber(_elderProfile!.phone!)
                : null,
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── Emergency Contacts ───────────────────────────────────
          Text(
            'Emergency Contacts',
            style: AppTextStyles.heading.copyWith(fontSize: 18),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_familyContacts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Text(
                'No emergency contacts added yet.',
                style: AppTextStyles.body,
              ),
            )
          else
            ..._familyContacts.map((c) => _ContactTile(
                  contact: c,
                  onCall: () => _callNumber(c.phone),
                  onMessage: () => _messageNumber(c.phone),
                )),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.onCall,
    required this.onMessage,
  });

  final UserProfile? profile;
  final VoidCallback? onCall;
  final VoidCallback? onMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withAlpha(20),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 42,
            backgroundColor: AppColors.primaryBlueLight,
            backgroundImage: profile?.photoUrl != null
                ? NetworkImage(profile!.photoUrl!)
                : null,
            child: profile?.photoUrl == null
                ? const Icon(Icons.person_rounded,
                    size: 48, color: AppColors.cardWhite)
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            profile?.name ?? 'Loading...',
            style: AppTextStyles.heading.copyWith(fontSize: 22),
          ),
          if (profile?.email != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              profile!.email!,
              style: AppTextStyles.body.copyWith(fontSize: 14),
            ),
          ],
          if (profile?.phone != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              profile!.phone!,
              style: AppTextStyles.body.copyWith(fontSize: 14),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (onCall != null)
                _CircleAction(
                  icon: Icons.call_rounded,
                  color: AppColors.successGreen,
                  label: 'Call',
                  onTap: onCall!,
                ),
              if (onCall != null && onMessage != null)
                const SizedBox(width: AppSpacing.xl),
              if (onMessage != null)
                _CircleAction(
                  icon: Icons.message_rounded,
                  color: AppColors.primaryBlue,
                  label: 'Message',
                  onTap: onMessage!,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.contact,
    required this.onCall,
    required this.onMessage,
  });

  final FamilyContact contact;
  final VoidCallback onCall;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.chipBlueLight,
            child: Text(
              contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
              style: AppTextStyles.heading.copyWith(
                fontSize: 18,
                color: AppColors.primaryBlue,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      contact.name,
                      style: AppTextStyles.heading.copyWith(fontSize: 15),
                    ),
                    if (contact.isCaregiver) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withAlpha(25),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusPill),
                        ),
                        child: Text(
                          'Caregiver',
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 10,
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  contact.phone,
                  style: AppTextStyles.body.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.call_rounded, color: AppColors.successGreen),
            onPressed: onCall,
            tooltip: 'Call',
          ),
          IconButton(
            icon: const Icon(Icons.message_rounded, color: AppColors.primaryBlue),
            onPressed: onMessage,
            tooltip: 'Message',
          ),
        ],
      ),
    );
  }
}
