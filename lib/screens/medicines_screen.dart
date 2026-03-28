import 'package:flutter/material.dart';

import '../core/constants/app_spacing.dart';
import '../core/models/medicine.dart';
import '../core/services/medicine_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import 'add_medicine_screen.dart';

class MedicinesScreen extends StatefulWidget {
  const MedicinesScreen({super.key});

  @override
  State<MedicinesScreen> createState() => _MedicinesScreenState();
}

class _MedicinesScreenState extends State<MedicinesScreen> {
  @override
  void initState() {
    super.initState();
    MedicineService.instance.addListener(_onChanged);
  }

  @override
  void dispose() {
    MedicineService.instance.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  // Sort: upcoming first, then later today, then taken, then as-needed
  List<Medicine> get _sorted {
    const order = {
      MedicineStatus.upcoming: 0,
      MedicineStatus.laterToday: 1,
      MedicineStatus.taken: 2,
      MedicineStatus.asNeeded: 3,
    };
    return List<Medicine>.from(MedicineService.instance.medicines)
      ..sort((a, b) =>
          (order[a.status] ?? 9).compareTo(order[b.status] ?? 9));
  }

  @override
  Widget build(BuildContext context) {
    final medicines = _sorted;

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
                  // ── Header ───────────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Daily Medicines',
                            style:
                                AppTextStyles.heading.copyWith(fontSize: 32),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            medicines.isEmpty
                                ? 'No medicines added yet'
                                : '${medicines.length} medicine${medicines.length == 1 ? '' : 's'} today',
                            style: AppTextStyles.body.copyWith(fontSize: 15),
                          ),
                        ],
                      ),
                      Container(
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
                        child: const Icon(Icons.notifications_rounded,
                            size: 22, color: AppColors.iconMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // ── Medicine cards ────────────────────────────────────────
                  if (medicines.isEmpty)
                    _EmptyState()
                  else
                    ...medicines.map((m) => Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppSpacing.md),
                          child: _MedicineCard(
                            medicine: m,
                            onToggleTaken: () =>
                                MedicineService.instance.toggleTaken(m.id),
                            onDelete: () => _confirmDelete(m),
                          ),
                        )),

                  const SizedBox(height: 100),
                ]),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddMedicineScreen()),
        ),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded, size: 32),
      ),
    );
  }

  Future<void> _confirmDelete(Medicine m) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg)),
        title: const Text('Remove Medicine?'),
        content: Text('Remove ${m.name} from your schedule?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style:
                    AppTextStyles.linkText.copyWith(color: AppColors.textGray)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Remove',
                style: AppTextStyles.linkText
                    .copyWith(color: AppColors.errorRed)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await MedicineService.instance.remove(m.id);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _MedicineCard
// ─────────────────────────────────────────────────────────────────────────────
class _MedicineCard extends StatelessWidget {
  const _MedicineCard({
    required this.medicine,
    required this.onToggleTaken,
    required this.onDelete,
  });

  final Medicine medicine;
  final VoidCallback onToggleTaken;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final status = medicine.status;
    final (statusLabel, statusColor, statusIcon, pillBg) =
        _statusVisuals(status);

    return Dismissible(
      key: Key(medicine.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.errorRed.withAlpha(30),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: const Icon(Icons.delete_rounded, color: AppColors.errorRed),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false; // let onDelete handle it
      },
      child: Material(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          onTap: status != MedicineStatus.asNeeded ? onToggleTaken : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.md),
            child: Row(
              children: [
                // Pill icon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: pillBg,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Icon(Icons.medication_rounded,
                      color: statusColor, size: 30),
                ),
                const SizedBox(width: AppSpacing.md),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(statusIcon, size: 14, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        medicine.name,
                        style: AppTextStyles.body.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        medicine.frequency == MedicineFrequency.onlyAsNeeded
                            ? medicine.dosage
                            : medicine.timeLabel,
                        style: AppTextStyles.body.copyWith(
                          fontSize: 14,
                          color: AppColors.textGray,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.iconMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static (String, Color, IconData, Color) _statusVisuals(MedicineStatus s) {
    switch (s) {
      case MedicineStatus.taken:
        return (
          'TAKEN',
          const Color(0xFF16A34A),
          Icons.check_circle_rounded,
          const Color(0xFFF0FDF4),
        );
      case MedicineStatus.upcoming:
        return (
          'UPCOMING',
          AppColors.primaryBlue,
          Icons.access_time_rounded,
          const Color(0xFFEFF6FF),
        );
      case MedicineStatus.laterToday:
        return (
          'LATER TODAY',
          AppColors.iconMuted,
          Icons.schedule_rounded,
          AppColors.inputBackground,
        );
      case MedicineStatus.asNeeded:
        return (
          'AS NEEDED',
          const Color(0xFFF59E0B),
          Icons.info_outline_rounded,
          const Color(0xFFFFFBEB),
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _EmptyState
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.medication_rounded,
                size: 40, color: AppColors.primaryBlueLight),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'No medicines yet',
            style: AppTextStyles.body.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add your first medicine.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(fontSize: 15),
          ),
        ],
      ),
    );
  }
}
