import 'package:flutter/material.dart';

class PriceTag extends StatelessWidget {
  const PriceTag({super.key, required this.priceInPaise, required this.tier});

  final int priceInPaise;
  final String tier;

  @override
  Widget build(BuildContext context) {
    final rupees = (priceInPaise / 100).toStringAsFixed(2);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('₹$rupees', style: Theme.of(context).textTheme.titleMedium),
        if (tier == 'trade') ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('Trade', style: TextStyle(fontSize: 11)),
          ),
        ],
      ],
    );
  }
}
