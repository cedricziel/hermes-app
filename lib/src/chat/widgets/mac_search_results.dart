import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../macos/mac_source_list.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../chat_models.dart';
import '../thread_search.dart';
import 'relative_time.dart';

/// [hits] split into the chats whose title holds [query] and those that
/// only matched in their messages, each in the order given.
({List<ThreadSearchHit> chats, List<ThreadSearchHit> messages}) splitSearchHits(
  String query,
  List<ThreadSearchHit> hits,
) {
  final needle = query.trim().toLowerCase();
  final chats = <ThreadSearchHit>[];
  final messages = <ThreadSearchHit>[];
  for (final hit in hits) {
    (hit.title.toLowerCase().contains(needle) ? chats : messages).add(hit);
  }
  return (chats: chats, messages: messages);
}

/// What a Mac sidebar shows while a search is open: a scope switch, then the
/// recent searches for an empty [query], or the hits grouped into Chats
/// (title matches) and Messages.
class MacSearchResults extends StatelessWidget {
  const MacSearchResults({
    super.key,
    required this.query,
    required this.status,
    required this.hits,
    required this.scope,
    required this.recent,
    required this.onOpen,
    required this.onPickRecent,
    this.onScopeChanged,
    this.currentProfile,
    this.selectedId,
  });

  final String query;
  final ThreadSearchStatus status;
  final List<ThreadSearchHit> hits;
  final ThreadSearchScope scope;
  final List<String> recent;
  final ValueChanged<ThreadSearchHit> onOpen;
  final ValueChanged<String> onPickRecent;

  /// Switches the scope; without it the switch is left out.
  final ValueChanged<ThreadSearchScope>? onScopeChanged;

  /// The profile the sidebar lists. Hits from others name theirs.
  final String? currentProfile;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final onScopeChanged = this.onScopeChanged;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onScopeChanged != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            child: CupertinoSlidingSegmentedControl<ThreadSearchScope>(
              key: const Key('search-scope'),
              groupValue: scope,
              onValueChanged: (value) {
                if (value != null) onScopeChanged(value);
              },
              children: const {
                ThreadSearchScope.profile: Text(
                  'This profile',
                  style: TextStyle(fontSize: 12),
                ),
                ThreadSearchScope.allProfiles: Text(
                  'All profiles',
                  style: TextStyle(fontSize: 12),
                ),
              },
            ),
          ),
        Expanded(child: _body(context)),
      ],
    );
  }

  Widget _body(BuildContext context) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return _recent(context);
    if (status == ThreadSearchStatus.loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator.adaptive(strokeWidth: 2),
          ),
        ),
      );
    }
    if (status == ThreadSearchStatus.failed) {
      return const _Note('Search failed. Check the connection.');
    }
    if (hits.isEmpty) return _Note('No results for “$trimmed”');
    final (:chats, :messages) = splitSearchHits(query, hits);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      children: [
        for (final (label, group) in [('Chats', chats), ('Messages', messages)])
          if (group.isNotEmpty) ...[
            _GroupHeader(label: label, count: group.length),
            for (final hit in group)
              MacSearchHitRow(
                key: ValueKey('search-hit-${hit.profile}-${hit.id}'),
                hit: hit,
                selected: hit.id == selectedId && _onCurrentProfile(hit),
                profileLabel: _onCurrentProfile(hit) ? null : hit.profile,
                onTap: () => onOpen(hit),
              ),
          ],
      ],
    );
  }

  bool _onCurrentProfile(ThreadSearchHit hit) =>
      hit.profile == null || hit.profile == currentProfile;

  Widget _recent(BuildContext context) {
    if (recent.isEmpty) {
      return const _Note('Search your chats by title or text.');
    }
    final subtle = context.hermesColors.subtleText;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      children: [
        const _GroupHeader(label: 'Recent searches'),
        for (final query in recent)
          Semantics(
            button: true,
            child: MacSourceListTile(
              onTap: () => onPickRecent(query),
              builder: (context, _) => Row(
                children: [
                  AppIcon(AppIcons.history, size: 14, color: subtle),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      query,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label, this.count});

  final String label;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: context.hermesColors.subtleText,
    );
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
        child: Row(
          children: [
            Expanded(child: Text(label, style: style)),
            if (count != null) Text('$count', style: style),
          ],
        ),
      ),
    );
  }
}

/// One search hit in a Mac sidebar: the title in bold with when it was last
/// active, then two lines of the matched text with the matches marked. A hit
/// from another profile names [profileLabel] first.
class MacSearchHitRow extends StatelessWidget {
  const MacSearchHitRow({
    super.key,
    required this.hit,
    required this.onTap,
    this.selected = false,
    this.profileLabel,
  });

  final ThreadSearchHit hit;
  final VoidCallback onTap;
  final bool selected;
  final String? profileLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtle = context.hermesColors.subtleText;
    final profileLabel = this.profileLabel;
    final radius = BorderRadius.circular(6);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? macSourceListSelectedFill(context)
            : Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                          fontWeight: FontWeight.w600,
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
                if (hit.snippet.isNotEmpty || profileLabel != null) ...[
                  const SizedBox(height: 2),
                  Text.rich(
                    TextSpan(
                      children: [
                        if (profileLabel != null)
                          TextSpan(
                            text: '$profileLabel · ',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        for (final part in hit.snippet)
                          TextSpan(
                            text: part.text,
                            style: part.match
                                ? TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: scheme.onSurface,
                                    backgroundColor:
                                        scheme.surfaceContainerHigh,
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
          ),
        ),
      ),
    );
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
