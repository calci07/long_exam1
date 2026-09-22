import 'package:flutter/material.dart';

class CustomInkwellButton extends StatelessWidget {
  const CustomInkwellButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? Theme.of(context).colorScheme.primary : null,
            ),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
      ),
    ),
  );
}
