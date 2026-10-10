import 'package:flutter/material.dart';

import '../../theme/platform_chrome.dart';
import '../../widgets/grouped_list.dart';
import '../hermes_mcp_repository.dart';
import '../mcp_presentation.dart';

/// A server in the grouped list: its initial in a tile, its name, its address
/// (a command in a monospaced font) and its facts, "Sign in needed" in the
/// warning colour, and its switch. A Mac row puts the address and the facts
/// on one line.
class McpServerRow extends StatelessWidget {
  const McpServerRow({
    super.key,
    required this.server,
    this.tested,
    this.selected = false,
    this.switching = false,
    required this.onTap,
    required this.onSwitch,
  });

  final HermesMcpServer server;

  /// The last finished test, which adds the tool count or the sign-in note.
  final HermesMcpTestResult? tested;

  /// Highlights the server whose detail shows beside the list.
  final bool selected;

  /// Disables the switch while a change is on its way.
  final bool switching;
  final VoidCallback onTap;
  final ValueChanged<bool> onSwitch;

  @override
  Widget build(BuildContext context) {
    final mac = platformChromeOf(context) == PlatformChrome.macos;
    final meta = mcpServerMeta(server, tested);
    final address = server.address;
    final control = MergeSemantics(
      child: Semantics(
        label: server.name,
        child: Switch.adaptive(
          value: server.enabled,
          onChanged: switching ? null : onSwitch,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
    final subtitle = [
      if (address.isNotEmpty) address,
      if (mac && meta.isNotEmpty) meta,
    ].join(' · ');
    // Beside a row that opens the detail, the switch is its own node, named
    // by the server.
    return GroupedRow(
      title: server.name,
      leading: GroupedTile(
        child: Text(server.name.characters.first.toUpperCase()),
      ),
      subtitle: subtitle.isEmpty ? null : subtitle,
      monospaceSubtitle: server.transport == McpTransport.command,
      caption: !mac && meta.isNotEmpty ? meta : null,
      warning: tested?.signInNeeded ?? false ? 'Sign in needed' : null,
      selected: selected,
      onTap: onTap,
      chevron: false,
      trailing: mac
          ? SizedBox(height: 22, child: FittedBox(child: control))
          : control,
    );
  }
}
