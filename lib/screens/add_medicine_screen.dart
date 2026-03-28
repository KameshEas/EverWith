import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../core/constants/app_spacing.dart';
import '../core/models/medicine.dart';
import '../core/services/medicine_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

class AddMedicineScreen extends StatefulWidget {
  const AddMedicineScreen({super.key});

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  final _nameCtrl = TextEditingController();
  final _dosageCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  TimeOfDay _selectedTime = const TimeOfDay(hour: 8, minute: 0);
  MedicineFrequency _frequency = MedicineFrequency.everyDay;

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _listening = false;
  bool _speechAvailable = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dosageCtrl.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _startListening() async {
    if (!_speechAvailable) return;
    setState(() => _listening = true);

    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          final text = result.recognizedWords.trim();
          if (_nameCtrl.text.isEmpty) {
            _nameCtrl.text = text;
          } else {
            _dosageCtrl.text = text;
          }
          setState(() => _listening = false);
        }
      },
      listenFor: const Duration(seconds: 10),
      listenOptions: stt.SpeechListenOptions(cancelOnError: true),
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() => _listening = false);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          timePickerTheme: TimePickerThemeData(
            backgroundColor: AppColors.cardWhite,
            hourMinuteShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final med = Medicine(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameCtrl.text.trim(),
      dosage: _dosageCtrl.text.trim(),
      timeHour: _selectedTime.hour,
      timeMinute: _selectedTime.minute,
      frequency: _frequency,
      takenDates: const [],
    );

    await MedicineService.instance.add(med);

    if (mounted) {
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
            builder: (_) => _MedicineSuccessScreen(medicine: med)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Container(
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(6),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: AppColors.textDark),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Add Medicine', style: AppTextStyles.heading),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            children: [
              const SizedBox(height: AppSpacing.md),

              // ── Voice Input ───────────────────────────────────────────────
              GestureDetector(
                onTap: _listening ? _stopListening : _startListening,
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: _listening
                        ? AppColors.primaryBlue.withAlpha(20)
                        : const Color(0xFFEFF6FF),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(
                      color: _listening
                          ? AppColors.primaryBlue
                          : const Color(0xFFBFDBFE),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _listening ? Icons.mic_rounded : Icons.mic_none_rounded,
                        color: _listening
                            ? AppColors.primaryBlue
                            : AppColors.primaryBlueLight,
                        size: 26,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _listening ? 'Listening…' : 'Voice Input',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: _listening
                              ? AppColors.primaryBlue
                              : AppColors.primaryBlueLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: AppSpacing.xl),

              // ── Medicine Name ─────────────────────────────────────────────
              _label('Medicine Name'),
              const SizedBox(height: 8),
              _inputField(
                controller: _nameCtrl,
                hint: 'Enter name (e.g., Aspirin)',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Dosage ────────────────────────────────────────────────────
              _label('Dosage'),
              const SizedBox(height: 8),
              _inputField(
                controller: _dosageCtrl,
                hint: 'e.g., 1 pill',
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Dosage is required'
                    : null,
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Time ──────────────────────────────────────────────────────
              _label('Time'),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickTime,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.inputBackground,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusSm),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_rounded,
                          color: AppColors.primaryBlueLight, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        _selectedTime.format(context),
                        style: AppTextStyles.body.copyWith(
                            fontSize: 16, color: AppColors.textDark),
                      ),
                      const Spacer(),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppColors.iconMuted),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Frequency ─────────────────────────────────────────────────
              _label('How often?'),
              const SizedBox(height: 8),
              ...MedicineFrequency.values.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _FrequencyTile(
                      frequency: f,
                      selected: _frequency == f,
                      onTap: () => setState(() => _frequency = f),
                    ),
                  )),

              const SizedBox(height: AppSpacing.xl),

              // ── Save ──────────────────────────────────────────────────────
              SizedBox(
                height: 58,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Save Medicine',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: AppTextStyles.body.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: AppColors.textDark),
      );

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: controller,
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              AppTextStyles.body.copyWith(color: AppColors.textGray, fontSize: 15),
          filled: true,
          fillColor: AppColors.inputBackground,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.md),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            borderSide:
                const BorderSide(color: AppColors.primaryBlue, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            borderSide:
                const BorderSide(color: AppColors.errorRed, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            borderSide:
                const BorderSide(color: AppColors.errorRed, width: 1.5),
          ),
        ),
        style: AppTextStyles.body.copyWith(fontSize: 16, color: AppColors.textDark),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  _FrequencyTile
// ─────────────────────────────────────────────────────────────────────────────
class _FrequencyTile extends StatelessWidget {
  const _FrequencyTile({
    required this.frequency,
    required this.selected,
    required this.onTap,
  });

  final MedicineFrequency frequency;
  final bool selected;
  final VoidCallback onTap;

  static const _labels = {
    MedicineFrequency.everyDay: 'Every Day',
    MedicineFrequency.twiceADay: 'Twice a Day',
    MedicineFrequency.onlyAsNeeded: 'Only as Needed',
  };

  static const _icons = {
    MedicineFrequency.everyDay: Icons.repeat_rounded,
    MedicineFrequency.twiceADay: Icons.repeat_one_rounded,
    MedicineFrequency.onlyAsNeeded: Icons.touch_app_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 56,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEFF6FF) : AppColors.inputBackground,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: Border.all(
            color: selected ? AppColors.primaryBlue : const Color(0xFFE2E8F0),
            width: selected ? 1.5 : 1,
          ),
        ),
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Row(
          children: [
            Icon(
              _icons[frequency],
              color: selected ? AppColors.primaryBlue : AppColors.iconMuted,
              size: 22,
            ),
            const SizedBox(width: 12),
            Text(
              _labels[frequency] ?? '',
              style: TextStyle(
                fontSize: 16,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
                color:
                    selected ? AppColors.primaryBlue : AppColors.textDark,
              ),
            ),
            const Spacer(),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? AppColors.primaryBlue
                      : const Color(0xFFCBD5E1),
                  width: 2,
                ),
                color: selected ? AppColors.primaryBlue : Colors.transparent,
              ),
              child: selected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Success Screen
// ─────────────────────────────────────────────────────────────────────────────
class _MedicineSuccessScreen extends StatefulWidget {
  const _MedicineSuccessScreen({required this.medicine});

  final Medicine medicine;

  @override
  State<_MedicineSuccessScreen> createState() =>
      _MedicineSuccessScreenState();
}

class _MedicineSuccessScreenState extends State<_MedicineSuccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.medicine;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Column(
            children: [
              const Spacer(flex: 2),
              ScaleTransition(
                scale: _scale,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF0FDF4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded,
                      size: 56, color: Color(0xFF16A34A)),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Medicine Added\nSuccessfully!',
                textAlign: TextAlign.center,
                style: AppTextStyles.heading.copyWith(
                    fontSize: 30, height: 1.25),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '${m.name} (${m.dosage}) has been added\nto your daily schedule.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(fontSize: 16),
              ),
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    // Pop back past AddMedicineScreen → MedicinesScreen
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Go to Medicines',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                          builder: (_) => const AddMedicineScreen()),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryBlue,
                    side: const BorderSide(
                        color: AppColors.primaryBlue, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd)),
                  ),
                  child: const Text(
                    'Add Another Medicine',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
