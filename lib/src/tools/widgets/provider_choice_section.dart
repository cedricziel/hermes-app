import 'package:flutter/material.dart';

import '../../widgets/grouped_list.dart';
import 'provider_row.dart';
import 'status_chip.dart';

/// One choice of a [ProviderChoiceSection], as plain values. [id] is what
/// [ProviderChoiceSection.onPick] reports; it may differ from [name] when
/// two choices of a group could read the same.
class ProviderChoice {
  const ProviderChoice({
    required this.id,
    required this.name,
    required this.status,
    required this.picked,
    this.badge,
    this.line,
    this.needsNousSignIn = false,
    this.hermesText,
    this.commandsWillFail = false,
  });

  final String id;
  final String name;
  final ToolsStatus status;
  final bool picked;
  final String? badge;
  final String? line;
  final bool needsNousSignIn;
  final String? hermesText;
  final bool commandsWillFail;
}

/// A group of [ProviderRow]s that picks one: the providers of a toolset, the
/// Search and Extract choices of Web, or the backends of Terminal. The
/// picked row is inert, since choosing it again sends nothing; [enabled]
/// false (a write is out) dims the rows and ignores taps.
class ProviderChoiceSection extends StatelessWidget {
  const ProviderChoiceSection({
    super.key,
    required this.choices,
    required this.onPick,
    this.header,
    this.footer,
    this.enabled = true,
  });

  final List<ProviderChoice> choices;
  final ValueChanged<String> onPick;
  final String? header;
  final String? footer;
  final bool enabled;

  @override
  Widget build(BuildContext context) => GroupedSection(
    header: header,
    footer: footer,
    dividerIndent: ProviderRow.dividerIndent(context),
    children: [
      for (final choice in choices)
        ProviderRow(
          key: ValueKey('provider-${choice.id}'),
          name: choice.name,
          status: choice.status,
          picked: choice.picked,
          badge: choice.badge,
          line: choice.line,
          needsNousSignIn: choice.needsNousSignIn,
          hermesText: choice.hermesText,
          commandsWillFail: choice.commandsWillFail,
          enabled: enabled,
          onPick: choice.picked || !enabled ? null : () => onPick(choice.id),
        ),
    ],
  );
}
