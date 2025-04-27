import 'package:flutter/material.dart';
import '../../utils/app_utils/AppUtils.dart';

class MessageInputTextField extends StatefulWidget {
  final String? errorText;
  final String? labelText;
  final String? hintText;
  final FocusNode? focusNode;
  final TextEditingController? controller;
  final void Function(String)? onTextChanged;

  const MessageInputTextField({
    super.key,
    this.controller,
    this.onTextChanged,
    this.labelText,
    this.hintText,
    this.errorText,
    this.focusNode,
  });

  @override
  State<MessageInputTextField> createState() => _MessageInputTextFieldState();
}

class _MessageInputTextFieldState extends State<MessageInputTextField> {
  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxHeight: 140, // Set max height (adjust as needed)
      ),
      child: TextField(
        maxLines: null,
        focusNode: widget.focusNode,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        controller: widget.controller,
        onChanged: widget.onTextChanged, // Call setState to rebuild the widget on text change
        decoration: InputDecoration(
          labelText: widget.labelText,
          hintText: widget.hintText,
          filled: true,
          fillColor: AppUtils.getColorScheme(context).secondary,
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
      ),
    );
  }
}