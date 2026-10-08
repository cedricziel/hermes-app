import 'package:flutter/material.dart';

import '../../theme/hermes_theme.dart';
import '../../widgets/grouped_list.dart';

/// The scrolling body of a plugin's or catalog entry's details: a header with
/// its [title], a muted [meta] line and its [description], then the grouped
/// [sections]. It sizes to its content, so a bottom sheet stays short.
class DetailPage extends StatelessWidget {
  const DetailPage({
    super.key,
    required this.title,
    this.meta = '',
    this.description = '',
    required this.sections,
  });

  final String title;

  /// A muted line under the title, such as "v1.2.0 · user".
  final String meta;
  final String description;
  final List<Widget> sections;

  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    final scheme = Theme.of(context).colorScheme;
    final muted = context.hermesColors.subtleText;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(metrics.gutter, 16, metrics.gutter, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: metrics.rowPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: metrics.titleSize + 3,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                if (meta.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      meta,
                      style: TextStyle(
                        fontSize: metrics.subtitleSize,
                        color: muted,
                      ),
                    ),
                  ),
                if (description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      description,
                      style: TextStyle(
                        fontSize: metrics.subtitleSize,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          ...sections,
        ],
      ),
    );
  }
}
