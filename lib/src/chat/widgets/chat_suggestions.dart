import 'package:flutter/material.dart';

import '../../widgets/grouped_list.dart';

class ChatSuggestion {
  const ChatSuggestion(this.title, this.description);
  final String title;
  final String description;
}

class ChatSuggestions extends StatefulWidget {
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
  State<ChatSuggestions> createState() => _ChatSuggestionsState();
}

class _ChatSuggestionsState extends State<ChatSuggestions> {
  final _scrollController = ScrollController();
  final _rowKeys = <int, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    _revealSelection();
  }

  @override
  void didUpdateWidget(ChatSuggestions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex ||
        oldWidget.items != widget.items) {
      _revealSelection();
    }
  }

  void _revealSelection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final row = _rowKeys[widget.selectedIndex]?.currentContext
          ?.findRenderObject();
      if (row == null || !row.attached) return;
      final position = _scrollController.position;
      position.ensureVisible(
        row,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
      position.ensureVisible(
        row,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: widget.maxHeight),
        child: SingleChildScrollView(
          controller: _scrollController,
          child: GroupedSection(
            header: widget.header,
            children: [
              for (final (index, item) in widget.items.indexed)
                GroupedRow(
                  key: _rowKeys.putIfAbsent(index, GlobalKey.new),
                  title: item.title,
                  subtitle: item.description,
                  chevron: false,
                  selected: widget.selectedIndex == index,
                  onTap: () => widget.onChoose(index),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
