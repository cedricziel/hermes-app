import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import '../../widgets/grouped_list.dart';
import '../../widgets/markdown_links.dart';

class SkillMarkdownPanel extends StatelessWidget {
  const SkillMarkdownPanel({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => GroupedSection(
    children: [
      Padding(
        padding: EdgeInsets.all(GroupedMetrics.of(context).rowPadding),
        child: GptMarkdown(text, onLinkTap: markdownLinkHandler()),
      ),
    ],
  );
}
