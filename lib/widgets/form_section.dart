import 'package:flutter/material.dart';

class FormSection extends StatelessWidget {
  final String? title;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  const FormSection({
    super.key,
    this.title,
    required this.children,
    this.padding = const EdgeInsets.symmetric(vertical: 16),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            SizedBox(height: 12),
          ],
          ...children.map((child) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: child,
              )),
        ],
      ),
    );
  }
}
