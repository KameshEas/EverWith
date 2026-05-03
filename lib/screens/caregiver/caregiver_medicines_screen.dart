import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/models/medicine.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../widgets/pill_chip.dart';

/// Tab 1 — Read-only view of the elder's medicine list.
///
/// Streams medicines from Firestore and groups them by status.
class CaregiverMedicinesScreen extends StatefulWidget {
  const CaregiverMedicinesScreen({super.key, required this.elderUid});

  final String? elderUid;

  @override
  State<CaregiverMedicinesScreen> createState() =>
      _CaregiverMedicinesScreenState();
}

class _CaregiverMedicinesScreenState extends State<CaregiverMedicinesScreen> {
  StreamSubscription<List<Medicine>>? _sub;
  List<Medicine> _medicines = [];

  @override
  void initState() {
    super.initState();
    if (widget.elderUid != null) {
      _sub = FirestoreService.instance
          .streamElderMedicines(widget.elderUid!)
          .listen((meds) {
        if (mounted) setState(() => _medicines = meds);
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.elderUid == null) {
      return const _EmptyState(message: 'Link to an elder to view medicines.');
    }

    final upcoming = _medicines
        .where((m) => m.status == MedicineStatus.upcoming)
        .toList();
    final laterToday = _medicines
        .where((m) => m.status == MedicineStatus.laterToday)
        .toList();
    final taken = _medicines
        .where((m) => m.status == MedicineStatus.taken)
        .toList();
    final asNeeded = _medicines
        .where((m) => m.status == MedicineStatus.asNeeded)
        .toList();

    final hasMeds = _medicines.isNotEmpty;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          // Firestore stream handles real-time updates; this is a UX affordance
          await Future<void>.delayed(const Duration(milliseconds: 500));
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          children: [
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Medicines',
              style: AppTextStyles.heading.copyWith(fontSize: 28),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Read-only view of your loved one\'s medicines',
              style: AppTextStyles.body.copyWith(fontSize: 14),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (!hasMeds) const _EmptyState(message: 'No medicines added yet.'),
            if (upcoming.isNotEmpty) ...[
              _SectionHeader('Upcoming', upcoming.length),
              const SizedBox(height: AppSpacing.sm),
              ...upcoming.map(_MedicineCard.new),
              const SizedBox(height: AppSpacing.lg),
            ],
            if (laterToday.isNotEmpty) ...[
              _SectionHeader('Later Today', laterToday.length),
              const SizedBox(height: AppSpacing.sm),
              ...laterToday.map(_MedicineCard.new),
              const SizedBox(height: AppSpacing.lg),
            ],
            if (taken.isNotEmpty) ...[
              _SectionHeader('Taken', taken.length),
              const SizedBox(height: AppSpacing.sm),
              ...taken.map(_MedicineCard.new),
              const SizedBox(height: AppSpacing.lg),
            ],
            if (asNeeded.isNotEmpty) ...[
              _SectionHeader('As Needed', asNeeded.length),
              const SizedBox(height: AppSpacing.sm),
              ...asNeeded.map(_MedicineCard.new),
            ],
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, this.count);
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: AppTextStyles.subheading.copyWith(fontSize: 16),
        ),
        const SizedBox(width: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withAlpha(25),
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          ),
          child: Text(
            '$count',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.primaryBlue,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _MedicineCard extends StatelessWidget {
  const _MedicineCard(this.medicine);
  final Medicine medicine;

  @override
  Widget build(BuildContext context) {
    final isTaken = medicine.status == MedicineStatus.taken;
    final isUpcoming = medicine.status == MedicineStatus.upcoming;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: isTaken
              ? AppColors.successGreen.withAlpha(80)
              : isUpcoming
                  ? AppColors.primaryBlue.withAlpha(60)
                  : AppColors.divider,
          width: 1,
        ),
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
          // Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isTaken
                  ? AppColors.successGreen.withAlpha(25)
                  : AppColors.primaryBlue.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isTaken
                  ? Icons.check_circle_rounded
                  : Icons.medication_rounded,
              color: isTaken ? AppColors.successGreen : AppColors.primaryBlue,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medicine.name,
                  style: AppTextStyles.heading.copyWith(fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${medicine.dosage} · ${medicine.timeLabel}',
                  style: AppTextStyles.body.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
          // Status chip
          PillChip(
            label: _statusLabel(medicine.status),
            backgroundColor: _statusColor(medicine.status).withAlpha(25),
            textStyle: AppTextStyles.caption.copyWith(
              color: _statusColor(medicine.status),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(MedicineStatus status) {
    switch (status) {
      case MedicineStatus.taken:
        return 'Taken ✓';
      case MedicineStatus.upcoming:
        return 'Upcoming';
      case MedicineStatus.laterToday:
        return 'Later';
      case MedicineStatus.asNeeded:
        return 'As Needed';
    }
  }

  Color _statusColor(MedicineStatus status) {
    switch (status) {
      case MedicineStatus.taken:
        return AppColors.successGreen;
      case MedicineStatus.upcoming:
        return AppColors.primaryBlue;
      case MedicineStatus.laterToday:
        return AppColors.textGray;
      case MedicineStatus.asNeeded:
        return AppColors.textGray;
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.medication_rounded,
                size: 56, color: AppColors.textGray.withAlpha(100)),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.body,
            ),
          ],
        ),
      ),
    );
  }
}
