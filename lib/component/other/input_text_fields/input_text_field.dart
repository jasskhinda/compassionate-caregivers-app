import 'package:flutter/material.dart';
import '../../../utils/app_utils/AppUtils.dart';

class InputTextField extends StatefulWidget {
  final String? errorText;
  final String? labelText;
  final String? hintText;
  final IconData? suffixIcon;
  final IconData? prefixIcon;
  final TextEditingController? controller;
  final void Function()? onIconPressed;
  final void Function(String)? onTextChanged;

  const InputTextField({
    super.key,
    this.controller,
    this.onTextChanged,
    this.labelText,
    this.hintText,
    this.suffixIcon,
    this.onIconPressed,
    this.errorText,
    this.prefixIcon
  });

  @override
  State<InputTextField> createState() => _InputTextFieldState();
}

class _InputTextFieldState extends State<InputTextField> {
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      onChanged: widget.onTextChanged,  // Call setState to rebuild the widget on text change
      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: widget.hintText,
        filled: true,
        fillColor: AppUtils.getColorScheme(context).secondary,
        prefixIcon: Icon(
          widget.prefixIcon,
          color: AppUtils.getColorScheme(context).onSurface, // Change prefix icon color
        ),
        suffixIcon: widget.controller!.text.isNotEmpty
            ? IconButton(
          icon: Icon(
            widget.suffixIcon,
            color: AppUtils.getColorScheme(context).onSurface, // Change suffix icon color
          ),
          onPressed: widget.onIconPressed,
        ) : null, // Show suffix icon only when text is not empty
        errorText: widget.errorText, // Show an error message if needed
        hintStyle: TextStyle(
          color: AppUtils.getColorScheme(context).onSurface.withAlpha(400),
        ),
        labelStyle: TextStyle(
          color: AppUtils.getColorScheme(context).onSurface.withAlpha(400),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15.0), // Set border radius
          borderSide: BorderSide.none, // Remove the underline
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15.0), // Set border radius for enabled state
          borderSide: BorderSide.none, // Remove the underline
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15.0), // Set border radius for focused state
          borderSide: BorderSide.none, // Remove the underline
        ),
      ),
      style: TextStyle(
        color: AppUtils.getColorScheme(context).onSurface, // Change text color
        fontSize: 16.0, // Change font size
      ),
      maxLines: 1,
    );
  }
}