import 'package:flutter/material.dart';

class UploadCard extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final IconData icon;
  final bool uploaded;

  const UploadCard({
    super.key,
    required this.label,
    required this.onTap,
    this.icon = Icons.upload_file,
    this.uploaded = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        width: double.infinity,
        margin: EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          border: Border.all(
            color: uploaded ? Colors.green : Colors.deepPurple.shade200,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: uploaded ? Colors.green : Colors.deepPurple),
              SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: uploaded ? Colors.green : Colors.deepPurple,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
