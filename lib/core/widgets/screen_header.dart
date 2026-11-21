import 'package:flutter/material.dart';
import 'package:pixora/core/widgets/pixora_logo.dart';

/// Large page title used by the History and Settings screens, with the small
/// brand mark for continuity.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    required this.title,
    required this.subtitle,
    this.showMark = true,
    super.key,
  });

  final String title;
  final String subtitle;
  final bool showMark;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (showMark) ...<Widget>[
          const PixoraLogo(size: 40, showGlow: false),
          const SizedBox(height: 18),
        ],
        Text(title, style: textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(subtitle, style: textTheme.bodyMedium),
      ],
    );
  }
}
