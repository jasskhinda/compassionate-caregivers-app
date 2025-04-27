import 'package:flutter/material.dart';

class TextInput extends StatelessWidget {
  final EdgeInsetsGeometry? contentPadding;
  final TextEditingController? controller;
  final void Function(String)? onChanged;
  final void Function()? onTap;
  final FocusNode? focusNode;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String labelText;
  final String errorText;
  final bool obscureText;
  final bool? isEnabled;
  final String hintText;
  final TextInputType? keyboardType;

  const TextInput({
    super.key,
    required this.controller,
    this.onChanged,
    required this.labelText,
    required this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    required this.errorText,
    required this.obscureText,
    this.contentPadding,
    this.onTap,
    this.focusNode,
    this.isEnabled,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      keyboardType: keyboardType,
      focusNode: focusNode,
      onTap: onTap,
      controller: controller,
      onChanged: onChanged,
      obscureText: obscureText,
      readOnly: isEnabled ?? false, // Make field non-editable if disabled
      decoration: InputDecoration(
        contentPadding: contentPadding ?? const EdgeInsets.all(10),
        labelText: labelText,
        hintText: hintText,
        fillColor: Theme.of(context).colorScheme.secondary,
        filled: true,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        errorText: errorText,
        hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(400)),
        labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(400)),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none
        ),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none
        ),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none
        ),
      ),
      style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface
      ),
      maxLines: 1,
    );
  }
}