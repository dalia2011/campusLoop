import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum BadgeTone { neutral, info, success, warning, danger }

/// A small label with an icon, e.g. "Registered" or "Full".
///
/// Status is always carried by the text AND an icon, never colour alone (an
/// accessibility rule in the spec). Every text/background pair below keeps at
/// least 4.5:1 contrast.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.icon,
    this.tone = BadgeTone.neutral,
  });

  final String label;
  final IconData icon;
  final BadgeTone tone;

  static (Color foreground, Color background) _colors(BadgeTone tone) {
    switch (tone) {
      case BadgeTone.info:
        return (AppColors.primary, AppColors.tint);
      case BadgeTone.success:
        return (const Color(0xFF0B6B52), const Color(0xFFE3F6F0));
      case BadgeTone.warning:
        return (const Color(0xFF8A4B00), const Color(0xFFFFF1DC));
      case BadgeTone.danger:
        return (AppColors.error, const Color(0xFFFDECEA));
      case BadgeTone.neutral:
        return (AppColors.muted, const Color(0xFFEFF2F7));
    }
  }

  @override
  Widget build(BuildContext context) {
    final (foreground, background) = _colors(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: foreground,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
