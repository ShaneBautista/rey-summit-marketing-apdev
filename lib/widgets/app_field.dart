import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// A rounded, shadowed text field with a leading icon and a label above it —
/// matches the "labeled input card" style used across Welcome / Login / Sign Up.
///
/// Uses TextFormField (not plain TextField) so it can sit inside a Form and
/// participate in Form.validate() — pass [validator] to enable that; screens
/// that don't wrap this in a Form can still use it exactly as before by
/// leaving [validator] null.
class AppField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;

  const AppField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.validator,
    this.textInputAction,
    this.autofillHints,
  });

  @override
  State<AppField> createState() => _AppFieldState();
}

class _AppFieldState extends State<AppField> {
  late bool _obscured = widget.obscure;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            color: kDarkGreen,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBorderGrey),
            boxShadow: const [
              BoxShadow(color: kShadowColor, blurRadius: 12, offset: Offset(0, 4)),
            ],
          ),
          child: TextFormField(
            controller: widget.controller,
            obscureText: _obscured,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            validator: widget.validator,
            autofillHints: widget.autofillHints,
            // Re-validates as the person types once they've already tried
            // to submit once — so an error clears itself the moment it's
            // fixed instead of sitting there until the next submit tap.
            autovalidateMode: AutovalidateMode.onUserInteraction,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              icon: Icon(widget.icon, color: kFieldGrey, size: 20),
              hintText: widget.hint,
              hintStyle: const TextStyle(color: kFieldGrey, fontSize: 14),
              border: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              errorStyle: const TextStyle(fontSize: 11, color: Colors.redAccent, height: 0.8),
              suffixIcon: widget.obscure
                  ? IconButton(
                      splashRadius: 18,
                      icon: Icon(
                        _obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: kFieldGrey,
                        size: 19,
                      ),
                      onPressed: () => setState(() => _obscured = !_obscured),
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
