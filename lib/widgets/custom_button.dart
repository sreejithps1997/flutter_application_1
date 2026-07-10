import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isDisabled;
  final Color? backgroundColor;
  final Color? textColor;
  final double? fontSize;
  final IconData? icon;
  final bool isSmall;

  const CustomButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.isDisabled = false,
    this.backgroundColor,
    this.textColor,
    this.fontSize,
    this.icon,
    this.isSmall = false, // ✅ NEW
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color effectiveTextColor = textColor ?? Colors.white;
    final double effectiveFontSize = fontSize ?? (isSmall ? 13 : 16);
    final EdgeInsetsGeometry padding = isSmall
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
        : const EdgeInsets.symmetric(vertical: 16);

    final ButtonStyle style = ElevatedButton.styleFrom(
      backgroundColor: backgroundColor ?? Theme.of(context).primaryColor,
      disabledBackgroundColor: Colors.grey.shade300,
      padding: padding,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );

    return icon != null
        ? ElevatedButton.icon(
            onPressed: isDisabled ? null : onPressed,
            icon: Icon(
              icon,
              size: isSmall ? 16 : 20,
              color: effectiveTextColor,
            ),
            label: Text(
              text,
              style: TextStyle(
                fontSize: effectiveFontSize,
                fontWeight: FontWeight.w600,
                color: effectiveTextColor,
              ),
            ),
            style: style,
          )
        : SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isDisabled ? null : onPressed,
              style: style,
              child: Text(
                text,
                style: TextStyle(
                  fontSize: effectiveFontSize,
                  fontWeight: FontWeight.w600,
                  color: effectiveTextColor,
                ),
              ),
            ),
          );
  }
}
