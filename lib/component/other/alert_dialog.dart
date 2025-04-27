import 'package:flutter/material.dart';

void alertDialog(BuildContext context, String text) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(title: Text(text))
  );
}