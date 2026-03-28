import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants/app_spacing.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  // ── Contact details ────────────────────────────────────────────────────
  static const String _supportPhone = 'tel:+18005551234';
  static const String _supportEmail = 'mailto:support@everwith.app';

  // ── FAQ content ────────────────────────────────────────────────────────
  static const List<_FaqItem> _faqs = [
    _FaqItem(
      icon: Icons.medication_rounded,
      iconColor: Color(0xFF7C3AED),
      question: 'How do I add a medicine?',
      answer:
          'Tap the "Medicines" tab at the bottom of the screen, then press the blue + button. '
          'Fill in the medicine name, dosage, time, and how often you take it, then tap "Save Medicine". '
          'You can also use Voice Input to speak the details.',
    ),
    _FaqItem(
      icon: Icons.group_rounded,
      iconColor: Color(0xFF2563EB),
      question: 'How do I call my family?',
      answer:
          'Open the "Family" tab. You will see your saved family contacts. '
          'Tap the phone icon next to a contact\'s name to call them directly.',
    ),
    _FaqItem(
      icon: Icons.record_voice_over_rounded,
      iconColor: Color(0xFF0891B2),
      question: 'How does voice control work?',
      answer:
          'Tap the microphone button in the centre of the bottom bar at any time. '
          'Speak a command like "Add medicine", "Call John", or "Open settings". '
          'EverWith listens and takes action automatically.',
    ),
  ];

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Header ──────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
                child: Row(
                  children: [
                    _CircleBackButton(onTap: () => Navigator.pop(context)),
                    const SizedBox(width: AppSpacing.md),
                    Text('Help & Support',
                        style: AppTextStyles.heading.copyWith(fontSize: 28)),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How can we help you today?',
                      style: AppTextStyles.body
                          .copyWith(fontSize: 17, color: AppColors.textGray),
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // ── Contact card ─────────────────────────────────────────
                    _ContactCard(
                      onCall: () => _launch(_supportPhone),
                      onEmail: () => _launch(_supportEmail),
                    ),

                    const SizedBox(height: AppSpacing.xxl),

                    // ── Common Questions header ──────────────────────────────
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.chipBlueLight,
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusSm),
                          ),
                          child: const Icon(Icons.quiz_rounded,
                              size: 20, color: AppColors.primaryBlue),
                        ),
                        const SizedBox(width: 10),
                        Text('Common Questions',
                            style: AppTextStyles.heading
                                .copyWith(fontSize: 22)),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // ── FAQ list ─────────────────────────────────────────────
                    ..._faqs.map((faq) => Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppSpacing.md),
                          child: _FaqTile(item: faq),
                        )),

                    const SizedBox(height: AppSpacing.lg),

                    // ── View Full Guide button ────────────────────────────────
                    _ViewGuideButton(
                        onTap: () => _launch(
                            'https://everwith.app/guide')),

                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _CircleBackButton
// ─────────────────────────────────────────────────────────────────────────────
class _CircleBackButton extends StatelessWidget {
  const _CircleBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withAlpha(38),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(Icons.arrow_back_ios_new_rounded,
            size: 18, color: AppColors.textDark),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _ContactCard
// ─────────────────────────────────────────────────────────────────────────────
class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.onCall, required this.onEmail});

  final VoidCallback onCall;
  final VoidCallback onEmail;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withAlpha(25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          // Agent avatar row
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.support_agent_rounded,
                    size: 32, color: AppColors.primaryBlue),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Contact Our Team',
                      style: AppTextStyles.body.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark)),
                  const SizedBox(height: 3),
                  Text('Available 24/7 for you',
                      style: AppTextStyles.body.copyWith(
                          fontSize: 14, color: AppColors.textGray)),
                ],
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          // Call Support button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: onCall,
              icon: const Icon(Icons.phone_rounded, size: 22),
              label: const Text('Call Support',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusMd)),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Email Us button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: onEmail,
              icon: const Icon(Icons.email_rounded, size: 22),
              label: const Text('Email Us',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.inputBackground,
                foregroundColor: AppColors.textDark,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusMd)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _FaqItem  (data class)
// ─────────────────────────────────────────────────────────────────────────────
class _FaqItem {
  const _FaqItem({
    required this.icon,
    required this.iconColor,
    required this.question,
    required this.answer,
  });

  final IconData icon;
  final Color iconColor;
  final String question;
  final String answer;
}

// ─────────────────────────────────────────────────────────────────────────────
//  _FaqTile — expandable FAQ card
// ─────────────────────────────────────────────────────────────────────────────
class _FaqTile extends StatefulWidget {
  const _FaqTile({required this.item});

  final _FaqItem item;

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _ctrl;
  late final Animation<double> _rotate;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _rotate = Tween<double>(begin: 0, end: 0.5).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor =
        Color.alphaBlend(widget.item.iconColor.withAlpha(20), Colors.white);

    return GestureDetector(
      onTap: _toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: _expanded
                ? AppColors.primaryBlue.withAlpha(80)
                : AppColors.divider,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withAlpha(15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Icon(widget.item.icon,
                        size: 24, color: widget.item.iconColor),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      widget.item.question,
                      style: AppTextStyles.body.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark),
                    ),
                  ),
                  RotationTransition(
                    turns: _rotate,
                    child: const Icon(Icons.chevron_right_rounded,
                        color: AppColors.iconMuted),
                  ),
                ],
              ),
            ),
            // Expanded answer
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 200),
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(color: AppColors.divider),
                    const SizedBox(height: 6),
                    Text(
                      widget.item.answer,
                      style: AppTextStyles.body.copyWith(
                          fontSize: 14,
                          color: AppColors.textGray,
                          height: 1.6),
                    ),
                  ],
                ),
              ),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _ViewGuideButton
// ─────────────────────────────────────────────────────────────────────────────
class _ViewGuideButton extends StatelessWidget {
  const _ViewGuideButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 58,
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withAlpha(15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'View Full Guide',
              style: AppTextStyles.body.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(width: 8),
            const Text('📖', style: TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
