import 'package:flutter/material.dart';

import '../chat/widgets/thread_sidebar.dart';
import '../theme/hermes_theme.dart';

/// One place the shell can show: the icon pair and the label of its entry.
typedef ShellDestination = ({IconData icon, IconData selected, String label});

/// The shell's destinations as sidebar rows, for a wide layout.
class ShellNavigation extends StatelessWidget {
  const ShellNavigation({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<ShellDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (i, d) in destinations.indexed)
          SidebarAction(
            icon: i == selectedIndex ? d.selected : d.icon,
            label: d.label,
            selected: i == selectedIndex,
            onTap: () => onSelected(i),
          ),
      ],
    );
  }
}

/// The sidebar next to a page that has no thread list of its own: the same
/// column as the chat's, so the destinations stay where they are.
class ShellSidebar extends StatelessWidget {
  const ShellSidebar({super.key, required this.navigation});

  final Widget navigation;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      color: context.hermesColors.sidebar,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Row(
                children: [
                  Icon(
                    Icons.hub_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Hermes',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: navigation,
            ),
            const Spacer(),
            const AccountFooter(),
          ],
        ),
      ),
    );
  }
}
