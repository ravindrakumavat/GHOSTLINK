import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// A placeholder navigation entry for a screen that isn't built yet
/// (Create SOS, Dashboard, Map, etc). Tapping shows a "coming soon"
/// message instead of navigating, since those destinations are later
/// phases and no functionality should be implemented for them here.
class NavPlaceholderButton extends StatelessWidget {
  const NavPlaceholderButton({
    super.key,
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label is coming soon.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.surfaceElevated,
          ),
        );
      },
      icon: Icon(icon, size: 20),
      label: Text(label),
    );
  }
}
