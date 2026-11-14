import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';

/// Shows [child] normally, and a blank surface in its place while the app is
/// inactive or hidden on a phone, so the app switcher's snapshot holds none
/// of the text. The child stays in the tree, hidden, so scroll positions and
/// what was typed are still there on return.
///
/// iOS and Android take that snapshot after Flutter stopped drawing, so the
/// blank has to be up as soon as the app goes inactive. macOS, Windows and
/// Linux take no such snapshot and are left alone. [blankWhenInactive] says
/// otherwise, for a test.
class PrivateSurface extends StatefulWidget {
  const PrivateSurface({
    super.key,
    required this.child,
    this.blankWhenInactive,
  });

  final Widget child;
  final bool? blankWhenInactive;

  @override
  State<PrivateSurface> createState() => _PrivateSurfaceState();
}

class _PrivateSurfaceState extends State<PrivateSurface>
    with WidgetsBindingObserver {
  late AppLifecycleState? _state = WidgetsBinding.instance.lifecycleState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      setState(() => _state = state);

  bool get _applies =>
      widget.blankWhenInactive ??
      (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.android));

  bool get _hidden =>
      _applies &&
      (_state == AppLifecycleState.inactive ||
          _state == AppLifecycleState.hidden ||
          _state == AppLifecycleState.paused);

  @override
  Widget build(BuildContext context) {
    final hidden = _hidden;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Offstage(offstage: hidden, child: widget.child),
        if (hidden)
          Positioned.fill(
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: Center(
                child: ExcludeSemantics(
                  child: AppIcon(
                    AppIcons.lock,
                    size: 40,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
