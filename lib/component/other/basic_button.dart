import 'package:flutter/material.dart';

class BasicButton extends StatelessWidget {
  final String text;
  final double? fontSize;
  final Color? textColor;
  final Color buttonColor;
  final void Function()? onPressed;

  const BasicButton({
    super.key,
    this.fontSize,
    this.textColor,
    this.onPressed,
    required this.text,
    required this.buttonColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 70,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 50.0),
        child: MaterialButton(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15)
          ),
          onPressed: onPressed,
          color: buttonColor,
          child: Text(
            text,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: textColor
            ),
          ),
        ),
      ),
    );
  }
}

class IconBasicButton extends StatelessWidget {
  final String text;
  final double? fontSize;
  final Color? textColor;
  final Color buttonColor;
  final IconData icon;
  final void Function()? onPressed;

  const IconBasicButton({
    super.key,
    this.fontSize,
    this.textColor,
    this.onPressed,
    required this.text,
    required this.buttonColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 70,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 50.0),
        child: MaterialButton(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15)
          ),
          onPressed: onPressed,
          color: buttonColor,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, color: textColor),
              Text(
                text,
                style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: textColor
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BasicTextButton extends StatelessWidget {
  final String text;
  final double? fontSize;
  final double? width;
  final Color? textColor;
  final Color buttonColor;
  final void Function()? onPressed;

  const BasicTextButton({
    super.key,
    this.width,
    this.fontSize,
    this.textColor,
    this.onPressed,
    required this.text,
    required this.buttonColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 70,
      child: MaterialButton(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15)
        ),
        onPressed: onPressed,
        color: buttonColor,
        child: Text(
          text,
          style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: textColor
          ),
        ),
      ),
    );
  }
}