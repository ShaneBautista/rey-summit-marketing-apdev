import 'package:flutter/material.dart';

import '../admin_colors.dart';

/// FIX: the previous version's Column (icon row + 14px gap + value text +
/// 2px gap + label text) was slightly taller than the fixed cell height
/// GridView.count(childAspectRatio: 1.5) gives it on narrower phones —
/// that's what produced the "BOTTOM OVERFLOWED BY 47 PIXELS" stripes.
/// This version tightens the internal spacing/padding and lets the label
/// wrap without forcing extra height, so it fits inside that same cell.
class StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final String? deltaLabel; // e.g. "+12%"
  final bool deltaPositive;

  const StatCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    this.deltaLabel,
    this.deltaPositive = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: kAdminShadow, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              if (deltaLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: (deltaPositive ? kAdminGreen : kAdminRed).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    deltaLabel!,
                    style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.bold, color: deltaPositive ? kAdminGreen : kAdminRed),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kAdminDarkBlue)),
          ),
          const SizedBox(height: 2),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: kAdminCardGrey, height: 1.2),
            ),
          ),
        ],
      ),
    );
  }
}
