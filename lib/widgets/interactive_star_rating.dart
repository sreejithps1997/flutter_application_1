import 'package:flutter/material.dart';

class InteractiveStarRating extends StatelessWidget {
  final double rating;
  final ValueChanged<double> onRatingChanged;
  final double size;

  const InteractiveStarRating({
    super.key,
    required this.rating,
    required this.onRatingChanged,
    this.size = 30,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        IconData icon = index < rating
            ? Icons.star
            : index < rating + 0.5
            ? Icons.star_half
            : Icons.star_border;

        return GestureDetector(
          onTap: () => onRatingChanged(index + 1.0),
          child: Icon(icon, color: Colors.amber, size: size),
        );
      }),
    );
  }
}
