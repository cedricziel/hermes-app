import 'package:flutter/material.dart';

import '../../widgets/grouped_list.dart';

class ChatSuggestion {
  const ChatSuggestion(this.title, this.description);
  final String title;
  final String description;
}

class ChatSuggestions extends StatelessWidget {
  const ChatSuggestions({
    super.key,
    required this.items,
    required this.onChoose,
    this.header,
    this.selectedIndex,
    this.maxHeight = 280,
  });

  final List<ChatSuggestion> items;
  final ValueChanged<int> onChoose;
  final String? header;
  final int? selectedIndex;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          child: GroupedSection(
            header: header,
            children: [
              for (final (index, item) in items.indexed)
                GroupedRow(
                  title: item.title,
                  subtitle: item.description,
                  chevron: false,
                  selected: selectedIndex == index,
                  onTap: () => onChoose(index),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
