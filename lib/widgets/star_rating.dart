import 'package:flutter/material.dart';

class StarRating extends StatelessWidget {
  final double rating; // Changed from int to double
  final double size;
  final Color color;

  const StarRating({
    super.key,
    required this.rating,
    this.size = 18,
    this.color = Colors.amber,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < rating.floor()) {
          return Icon(Icons.star, color: color, size: size);
        } else if (index < rating) {
          return Icon(Icons.star_half, color: color, size: size);
        } else {
          return Icon(Icons.star_border, color: color, size: size);
        }
      }),
    );
  }
}
