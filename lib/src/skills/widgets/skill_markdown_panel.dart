import 'package:flutter/material.dart';

import '../../widgets/app_markdown_theme.dart';
import '../../widgets/bounded_markdown.dart';
import '../../widgets/grouped_list.dart';
import '../../widgets/markdown_links.dart';
import '../../widgets/markdown_task_box.dart';

class SkillMarkdownPanel extends StatelessWidget {
  const SkillMarkdownPanel({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => GroupedSection(
    children: [
      Padding(
        padding: EdgeInsets.all(GroupedMetrics.of(context).rowPadding),
        child: AppMarkdownTheme(
          child: BoundedMarkdown(
            text,
            onLinkTap: markdownLinkHandler(),
            checkboxBuilder: readOnlyTaskBox,
            radioOptionBuilder: readOnlyRadioOption,
          ),
        ),
      ),
    ],
  );
}
