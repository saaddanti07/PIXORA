import 'package:flutter/material.dart';
import 'package:pixora/app/localization/l10n.dart';
import 'package:pixora/app/theme/app_spacing.dart';
import 'package:pixora/features/home/data/creative_tools.dart';
import 'package:pixora/features/home/widgets/tool_card.dart';

/// Two-column grid of creative tools.
///
/// Rows are laid out explicitly (instead of a GridView) so cards in the same
/// row always share a height — which keeps the grid even in French and Arabic,
/// where label lengths differ from English.
class ToolGrid extends StatelessWidget {
  const ToolGrid({required this.tools, required this.onToolSelected, super.key});

  final List<CreativeTool> tools;
  final ValueChanged<CreativeTool> onToolSelected;

  @override
  Widget build(BuildContext context) {
    final String comingSoonLabel = context.l10n.toolComingSoon;
    final List<Widget> rows = <Widget>[];

    for (int index = 0; index < tools.length; index += 2) {
      final CreativeTool first = tools[index];
      final CreativeTool? second = index + 1 < tools.length ? tools[index + 1] : null;
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: ToolCard(
                    tool: first,
                    comingSoonLabel: comingSoonLabel,
                    onTap: () => onToolSelected(first),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: second == null
                      ? const SizedBox.shrink()
                      : ToolCard(
                          tool: second,
                          comingSoonLabel: comingSoonLabel,
                          onTap: () => onToolSelected(second),
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(children: rows);
  }
}
