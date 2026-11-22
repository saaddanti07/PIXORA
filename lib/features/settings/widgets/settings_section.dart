import 'package:flutter/material.dart';
import 'package:pixora/app/theme/app_spacing.dart';
import 'package:pixora/core/widgets/section_header.dart';

/// Groups related settings under a title, with consistent spacing.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    required this.title,
    required this.child,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
          child: SectionHeader(title: title, subtitle: subtitle),
        ),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    );
  }
}
