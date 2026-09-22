import 'package:flutter/material.dart';

class CustomTextFormField extends StatelessWidget {
  const CustomTextFormField({
    super.key,
    required this.controller,
    required this.label,
    this.obscureText = false,
    this.suffixIcon,
    this.onSubmitted,
    this.autofillHints,
  });
  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final Widget? suffixIcon;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    obscureText: obscureText,
    autocorrect: false,
    enableSuggestions: !obscureText,
    autofillHints: autofillHints,
    onFieldSubmitted: onSubmitted,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      suffixIcon: suffixIcon,
    ),
    validator: (value) => value == null || value.trim().isEmpty
        ? 'Enter your ${label.toLowerCase()}.'
        : null,
  );
}
