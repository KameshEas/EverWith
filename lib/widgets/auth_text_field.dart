import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants/app_spacing.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

/// Accessible, elderly-friendly labeled text input for auth forms.
///
/// Features:
/// - Visible label above the field (not just a placeholder)
/// - Large tap target (min 60 px height)
/// - Inline error message with colour + icon
/// - Optional password visibility toggle
/// - Optional mic icon for voice-assisted input
/// - Optional suffix widget slot for country-code picker etc.
class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.prefixIcon,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.isPassword = false,
    this.showMicIcon = false,
    this.errorText,
    this.inputFormatters,
    this.onChanged,
    this.autofillHints,
    this.suffixWidget,
    this.focusNode,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final IconData? prefixIcon;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final bool isPassword;
  final bool showMicIcon;
  final String? errorText;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final Iterable<String>? autofillHints;
  final Widget? suffixWidget;
  final FocusNode? focusNode;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  bool _obscure = true;
  bool _isFocused = false;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() => setState(() => _isFocused = _focusNode.hasFocus);

  @override
  void dispose() {
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Field Label ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs + 2),
          child: Text(widget.label, style: AppTextStyles.inputLabel),
        ),

        // ── Input Field ──────────────────────────────────────────────────
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: hasError
                ? AppColors.errorRedLight
                : _isFocused
                    ? AppColors.cardWhite
                    : AppColors.inputBackground,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: hasError
                  ? AppColors.errorRed
                  : _isFocused
                      ? AppColors.inputBorderFocus
                      : AppColors.inputBorder,
              width: _isFocused || hasError ? 2 : 1.5,
            ),
            boxShadow: _isFocused && !hasError
                ? [
                    BoxShadow(
                      color: AppColors.primaryBlue.withOpacity(0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              // Prefix icon
              if (widget.prefixIcon != null)
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.md,
                    right: AppSpacing.sm,
                  ),
                  child: Icon(
                    widget.prefixIcon,
                    color: hasError
                        ? AppColors.errorRed
                        : _isFocused
                            ? AppColors.primaryBlue
                            : AppColors.textGray,
                    size: 22,
                  ),
                ),

              // Country-code / custom suffix on the left
              if (widget.suffixWidget != null) ...[
                widget.suffixWidget!,
                Container(
                  width: 1.5,
                  height: 28,
                  color: AppColors.inputBorder,
                  margin: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                ),
              ],

              // Text input
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  obscureText: widget.isPassword && _obscure,
                  keyboardType: widget.keyboardType,
                  textInputAction: widget.textInputAction,
                  style: AppTextStyles.inputText,
                  inputFormatters: widget.inputFormatters,
                  onChanged: widget.onChanged,
                  autofillHints: widget.autofillHints,
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    hintStyle: AppTextStyles.inputHint,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: widget.prefixIcon != null
                          ? 0
                          : AppSpacing.md,
                      vertical: AppSpacing.md + 2,
                    ),
                    isDense: false,
                  ),
                ),
              ),

              // Trailing: mic icon
              if (widget.showMicIcon && !widget.isPassword)
                Semantics(
                  label: 'Use voice input for ${widget.label}',
                  button: true,
                  child: GestureDetector(
                    onTap: () {
                      // TODO: wire to speech recognition
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm + 2,
                      ),
                      child: Icon(
                        Icons.mic_rounded,
                        color: AppColors.primaryBlue,
                        size: 22,
                      ),
                    ),
                  ),
                ),

              // Trailing: password toggle
              if (widget.isPassword)
                Semantics(
                  label: _obscure ? 'Show password' : 'Hide password',
                  button: true,
                  child: GestureDetector(
                    onTap: () => setState(() => _obscure = !_obscure),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm + 2,
                      ),
                      child: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.textGray,
                        size: 22,
                      ),
                    ),
                  ),
                ),

              const SizedBox(width: AppSpacing.xs),
            ],
          ),
        ),

        // ── Inline Error ─────────────────────────────────────────────────
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: hasError
              ? Padding(
                  padding: const EdgeInsets.only(
                    top: AppSpacing.xs,
                    left: AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.errorRed,
                        size: 16,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Flexible(
                        child: Text(
                          widget.errorText!,
                          style: AppTextStyles.inputError,
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
