import 'package:flutter/material.dart';

import '../../theme/hermes_theme.dart';
import '../../widgets/named_icon_button.dart';
import '../chat_models.dart';
import '../thread_search.dart';
import 'relative_time.dart';
import 'sidebar_row.dart';

/// The search field above the thread list. It shows [query] and reports each
/// edit; clearing it reports an empty query.
class ThreadSearchField extends StatefulWidget {
  const ThreadSearchField({
    super.key,
    required this.query,
    required this.onChanged,
  });

  final String query;
  final ValueChanged<String> onChanged;

  @override
  State<ThreadSearchField> createState() => _ThreadSearchFieldState();
}

class _ThreadSearchFieldState extends State<ThreadSearchField> {
  late final _text = TextEditingController(text: widget.query);

  @override
  void didUpdateWidget(ThreadSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != _text.text) _text.text = widget.query;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subtle = context.hermesColors.subtleText;
    return TextField(
      key: const Key('thread-search-field'),
      controller: _text,
      onChanged: widget.onChanged,
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Search chats',
        prefixIcon: Icon(Icons.search, size: 18, color: subtle),
        prefixIconConstraints: const BoxConstraints(minWidth: 36),
        suffixIcon: widget.query.isEmpty
            ? null
            : NamedIconButton(
                label: 'Clear search',
                iconSize: 16,
                visualDensity: VisualDensity.compact,
                icon: Icons.close,
                onPressed: () => widget.onChanged(''),
              ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
      ),
    );
  }
}

/// What the search found for [query], in place of the thread list.
class ThreadSearchResults extends StatelessWidget {
  const ThreadSearchResults({
    super.key,
    required this.query,
    required this.status,
    required this.hits,
    required this.onOpen,
    this.selectedId,
  });

  final String query;
  final ThreadSearchStatus status;
  final List<ThreadSearchHit> hits;
  final ValueChanged<ThreadSearchHit> onOpen;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      ThreadSearchStatus.loading => const Padding(
        padding: EdgeInsets.all(16),
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      ThreadSearchStatus.failed => _Note(
        'Search failed. Check the connection.',
      ),
      _ when hits.isEmpty => _Note('No chats match "${query.trim()}".'),
      _ => ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: hits.length,
        itemBuilder: (context, index) {
          final hit = hits[index];
          return _HitRow(
            key: ValueKey('search-hit-${hit.id}'),
            hit: hit,
            selected: hit.id == selectedId,
            onTap: () => onOpen(hit),
          );
        },
      ),
    };
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Text(
      text,
      style: TextStyle(fontSize: 13, color: context.hermesColors.subtleText),
    ),
  );
}

class _HitRow extends StatelessWidget {
  const _HitRow({
    super.key,
    required this.hit,
    required this.selected,
    required this.onTap,
  });

  final ThreadSearchHit hit;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtle = context.hermesColors.subtleText;
    return SidebarRow(
      selected: selected,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  hit.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                relativeTime(hit.updatedAt),
                style: TextStyle(fontSize: 11, color: subtle),
              ),
            ],
          ),
          if (hit.snippet.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text.rich(
              TextSpan(
                children: [
                  for (final part in hit.snippet)
                    TextSpan(
                      text: part.text,
                      style: part.match
                          ? TextStyle(
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                            )
                          : null,
                    ),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: subtle),
            ),
          ],
        ],
      ),
    );
  }
}
