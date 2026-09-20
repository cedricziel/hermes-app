import 'package:flutter/material.dart';

/// The content of a details bottom sheet that follows [listenable] and closes
/// the sheet when [isGone] says what it shows no longer exists.
class SheetHost extends StatefulWidget {
  const SheetHost({
    super.key,
    required this.listenable,
    required this.isGone,
    required this.builder,
  });

  final Listenable listenable;
  final bool Function() isGone;
  final WidgetBuilder builder;

  @override
  State<SheetHost> createState() => _SheetHostState();
}

class _SheetHostState extends State<SheetHost> {
  @override
  void initState() {
    super.initState();
    widget.listenable.addListener(_closeIfGone);
  }

  @override
  void dispose() {
    widget.listenable.removeListener(_closeIfGone);
    super.dispose();
  }

  void _closeIfGone() {
    if (widget.isGone() && mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.listenable,
      builder: (context, _) =>
          widget.isGone() ? const SizedBox(height: 1) : widget.builder(context),
    );
  }
}

/// Where a list sits beside its details: below this width the details open
/// in a bottom sheet.
const pluginsWideBreakpoint = 900.0;

/// A shared shell for a list with a details pane: at [pluginsWideBreakpoint]
/// the [detail] (or [placeholder]) sits beside [list], below it only [list]
/// is shown.
class ListWithDetail extends StatelessWidget {
  const ListWithDetail({
    super.key,
    required this.wide,
    required this.list,
    required this.detail,
    required this.placeholder,
  });

  final bool wide;
  final Widget list;
  final Widget? detail;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    if (!wide) return list;
    return Row(
      children: [
        SizedBox(width: 400, child: list),
        const VerticalDivider(width: 1),
        Expanded(child: detail ?? Center(child: Text(placeholder))),
      ],
    );
  }
}
