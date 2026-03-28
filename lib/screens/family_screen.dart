import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants/app_spacing.dart';
import '../core/services/family_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../widgets/confirm_bottom_sheet.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  final _svc = FamilyService.instance;

  @override
  void initState() {
    super.initState();
    _svc.addListener(_onChanged);
  }

  @override
  void dispose() {
    _svc.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _pickContact() async {
    // Ask for contacts permission via flutter_contacts built-in method
    final granted = await FlutterContacts.requestPermission(readonly: true);
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Contacts permission is required to add family members.'),
            backgroundColor: AppColors.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
          ),
        );
      }
      return;
    }

    // Open system contact picker
    final contact = await FlutterContacts.openExternalPick();
    if (contact == null) return;

    // Fetch full contact with phone numbers and photo
    final full = await FlutterContacts.getContact(contact.id,
        withPhoto: true, withProperties: true);
    if (full == null) return;

    final phones = full.phones;
    if (phones.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${full.displayName} has no phone number.'),
            backgroundColor: AppColors.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
          ),
        );
      }
      return;
    }

    // If multiple numbers, let user pick
    String phone = phones.first.number;
    if (phones.length > 1 && mounted) {
      final picked = await _showPhonePicker(full.displayName, phones);
      if (picked == null) return;
      phone = picked;
    }

    // Check for duplicates
    final alreadyAdded =
        _svc.contacts.any((c) => c.id == full.id || c.phone == phone);
    if (alreadyAdded) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${full.displayName} is already in your list.'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
          ),
        );
      }
      return;
    }

    // Encode avatar if available
    String? avatarB64;
    if (full.photo != null && full.photo!.isNotEmpty) {
      avatarB64 = base64Encode(full.photo!);
    }

    // If this is the first contact, make them caregiver automatically
    final isFirst = _svc.contacts.isEmpty;

    await _svc.add(FamilyContact(
      id: full.id,
      name: full.displayName,
      phone: phone,
      avatarBase64: avatarB64,
      isCaregiver: isFirst,
    ));

    if (isFirst && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${full.displayName} added as your priority caregiver.'),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
        ),
      );
    }
  }

  Future<String?> _showPhonePicker(
      String name, List<Phone> phones) async {
    return showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusLg)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.md),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.inputBorder,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Choose a number for $name',
                style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: AppSpacing.sm),
            ...phones.map((p) => ListTile(
                  leading: const Icon(Icons.phone_rounded,
                      color: AppColors.primaryBlue),
                  title: Text(p.number,
                      style: AppTextStyles.body.copyWith(fontSize: 16)),
                  subtitle: Text(p.label.name,
                      style: AppTextStyles.body
                          .copyWith(fontSize: 13, color: AppColors.textGray)),
                  onTap: () => Navigator.pop(ctx, p.number),
                )),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemove(FamilyContact c) async {
    final ok = await showConfirmSheet(
      context,
      icon: Icons.person_remove_rounded,
      title: 'Remove ${c.name}?',
      message: 'They will be removed from your family contacts list.',
      confirmLabel: 'Remove',
    );
    if (ok != true) return;

    await _svc.remove(c.id);

    // If the removed contact was the caregiver and others remain, prompt to choose a new one
    if (c.isCaregiver && _svc.contacts.isNotEmpty && mounted) {
      await _showPickCaregiverModal();
    }
  }

  Future<void> _showPickCaregiverModal() async {
    final others = _svc.contacts;
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppSpacing.radiusLg)),
        ),
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle (decorative only — sheet is non-dismissible)
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.inputBorder,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: AppSpacing.xl),
              // Star icon badge
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.chipBlueLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.star_rounded,
                    color: AppColors.primaryBlue, size: 30),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Choose a New Caregiver',
                  style: AppTextStyles.heading.copyWith(fontSize: 20),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Text(
                  'Select who should be your priority contact for emergencies.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body
                      .copyWith(fontSize: 14, color: AppColors.textGray),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              // Contact list
              ...others.map((c) => Padding(
                    padding:
                        const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: GestureDetector(
                      onTap: () async {
                        await _svc.setCaregiver(c.id);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.inputBackground,
                          borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMd),
                          border: Border.all(
                              color: AppColors.inputBorder, width: 1),
                        ),
                        child: Row(
                          children: [
                            _Avatar(contact: c, size: 46),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(c.name,
                                      style: AppTextStyles.body.copyWith(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16)),
                                  const SizedBox(height: 2),
                                  Text(c.phone,
                                      style: AppTextStyles.body.copyWith(
                                          fontSize: 13,
                                          color: AppColors.textGray)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: AppColors.chipBlueLight,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                  Icons.star_outline_rounded,
                                  color: AppColors.primaryBlue,
                                  size: 18),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contacts = _svc.contacts;
    final caregiver = _svc.caregiver;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── Header ──────────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Family',
                              style: AppTextStyles.heading
                                  .copyWith(fontSize: 32)),
                          const SizedBox(height: 4),
                          Text(
                            contacts.isEmpty
                                ? 'Add your family members'
                                : '${contacts.length} contact${contacts.length == 1 ? '' : 's'}',
                            style: AppTextStyles.body
                                .copyWith(fontSize: 15),
                          ),
                        ],
                      ),
                      _AddButton(onTap: _pickContact),
                    ],
                  ),

                  // ── Caregiver card ───────────────────────────────────────
                  if (caregiver != null) ...[
                    const SizedBox(height: AppSpacing.xl),
                    _CaregiverCard(
                      contact: caregiver,
                      onCall: () => _call(caregiver.phone),
                    ),
                  ],

                  // ── Other contacts ───────────────────────────────────────
                  if (contacts.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xl),
                    if (contacts.length > 1)
                      Padding(
                        padding:
                            const EdgeInsets.only(bottom: AppSpacing.md),
                        child: Text('All Contacts',
                            style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: AppColors.textGray)),
                      ),
                    ...contacts.map((c) => Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppSpacing.md),
                          child: _ContactCard(
                            contact: c,
                            onCall: () => _call(c.phone),
                            onSetCaregiver: c.isCaregiver
                                ? null
                                : () => _svc.setCaregiver(c.id),
                            onRemove: () => _confirmRemove(c),
                          ),
                        )),
                  ] else ...[
                    const SizedBox(height: 60),
                    _EmptyState(onAdd: _pickContact),
                  ],

                  const SizedBox(height: 100),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _AddButton
// ─────────────────────────────────────────────────────────────────────────────
class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.primaryBlue,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_add_rounded, size: 18, color: Colors.white),
            SizedBox(width: 6),
            Text('Add',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _CaregiverCard  — prominent card for the priority caregiver
// ─────────────────────────────────────────────────────────────────────────────
class _CaregiverCard extends StatelessWidget {
  const _CaregiverCard({required this.contact, required this.onCall});

  final FamilyContact contact;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withAlpha(80),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          _Avatar(contact: contact, size: 68, borderColor: Colors.white),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(50),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star_rounded,
                              size: 12, color: Colors.white),
                          SizedBox(width: 3),
                          Text('CAREGIVER',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(contact.name,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                const SizedBox(height: 2),
                Text(contact.phone,
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withAlpha(200))),
              ],
            ),
          ),
          // Big call button
          GestureDetector(
            onTap: onCall,
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.phone_rounded,
                  color: Color(0xFF2563EB), size: 26),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _ContactCard  — regular family member card
// ─────────────────────────────────────────────────────────────────────────────
class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.contact,
    required this.onCall,
    required this.onRemove,
    this.onSetCaregiver,
  });

  final FamilyContact contact;
  final VoidCallback onCall;
  final VoidCallback onRemove;
  final VoidCallback? onSetCaregiver;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(contact.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.errorRed.withAlpha(30),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: const Icon(Icons.person_remove_rounded,
            color: AppColors.errorRed),
      ),
      confirmDismiss: (_) async {
        onRemove();
        return false;
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withAlpha(15),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          leading: _Avatar(contact: contact, size: 52),
          title: Text(contact.name,
              style: AppTextStyles.body.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark)),
          subtitle: Text(contact.phone,
              style: AppTextStyles.body
                  .copyWith(fontSize: 13, color: AppColors.textGray)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onSetCaregiver != null)
                IconButton(
                  icon: const Icon(Icons.star_border_rounded,
                      color: AppColors.iconMuted),
                  tooltip: 'Set as caregiver',
                  onPressed: onSetCaregiver,
                ),
              if (contact.isCaregiver)
                const Icon(Icons.star_rounded,
                    color: Color(0xFFF59E0B), size: 20),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onCall,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.chipBlueLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.phone_rounded,
                      color: AppColors.primaryBlue, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _Avatar
// ─────────────────────────────────────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  const _Avatar({required this.contact, required this.size, this.borderColor});

  final FamilyContact contact;
  final double size;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final initials = contact.name
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();

    Uint8List? bytes;
    if (contact.avatarBase64 != null && contact.avatarBase64!.isNotEmpty) {
      try {
        bytes = base64Decode(contact.avatarBase64!);
      } catch (_) {}
    }

    Widget avatar;
    if (bytes != null) {
      avatar = CircleAvatar(
        radius: size / 2,
        backgroundImage: MemoryImage(bytes),
      );
    } else {
      avatar = CircleAvatar(
        radius: size / 2,
        backgroundColor: AppColors.chipBlueLight,
        child: Text(initials,
            style: TextStyle(
                fontSize: size * 0.35,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryBlue)),
      );
    }

    if (borderColor != null) {
      return Container(
        width: size + 4,
        height: size + 4,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor!, width: 2),
        ),
        child: avatar,
      );
    }
    return avatar;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _EmptyState
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
              color: Color(0xFFEFF6FF), shape: BoxShape.circle),
          child: const Icon(Icons.group_rounded,
              size: 40, color: AppColors.primaryBlueLight),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('No family contacts yet',
            style: AppTextStyles.body.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark)),
        const SizedBox(height: 8),
        Text('Add family members to call them quickly.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(fontSize: 15)),
        const SizedBox(height: AppSpacing.xl),
        ElevatedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.person_add_rounded),
          label: const Text('Add from Contacts',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl, vertical: AppSpacing.md),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
            elevation: 0,
          ),
        ),
      ],
    );
  }
}
