import 'package:flutter/material.dart';
import '../core/constants/theme_extensions.dart';

class CustomTextField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final String? prefixText;
  final String? suffixText;
  final IconData? prefixIcon;
  final String? helperText;

  const CustomTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType = const TextInputType.numberWithOptions(decimal: true),
    this.prefixText,
    this.suffixText,
    this.prefixIcon,
    this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: context.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: hint,
              prefixText: prefixText,
              suffixText: suffixText,
              prefixIcon: prefixIcon != null
                  ? Icon(prefixIcon, color: context.textSecondary, size: 20)
                  : null,
            ),
          ),
          if (helperText != null) ...[
            const SizedBox(height: 6),
            Text(
              helperText!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
