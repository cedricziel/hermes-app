import 'package:flutter/widgets.dart';

import '../../widgets/route_dismissal.dart';

/// Closes the dialog or menu route it sits in when [closer] fires, and does
/// nothing else.
///
/// A page marks the questions and menus it opens with this, so it can close
/// exactly those when what they were about goes stale, and leaves a dialog
/// that someone else put over it alone. Only a popup route (a dialog or a
/// menu) is closed: inside a page's own route this does nothing, so it is
/// safe to share with widgets that are not in a popup.
class ClosesWith extends StatefulWidget {
  const ClosesWith({super.key, required this.closer, required this.child});

  /// Null means never.
  final Listenable? closer;
  final Widget child;

  @override
  State<ClosesWith> createState() => _ClosesWithState();
}

class _ClosesWithState extends State<ClosesWith> {
  @override
  void initState() {
    super.initState();
    widget.closer?.addListener(_close);
  }

  @override
  void didUpdateWidget(ClosesWith old) {
    super.didUpdateWidget(old);
    if (old.closer == widget.closer) return;
    old.closer?.removeListener(_close);
    widget.closer?.addListener(_close);
  }

  @override
  void dispose() {
    widget.closer?.removeListener(_close);
    super.dispose();
  }

  void _close() {
    if (!mounted) return;
    if (ModalRoute.of(context) is PopupRoute) dismissRoute(context);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
