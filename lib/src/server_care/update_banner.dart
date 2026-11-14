import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../macos/mac_window.dart';
import '../theme/platform_chrome.dart';
import 'hermes_update_run.dart';
import 'widgets/server_restart_banner.dart';

/// Puts the restart banner above [child] while an update restarts Hermes or
/// checks it, and "Hermes `version` is ready" after a success it saw.
///
/// Only the shell's main window builds this: a conversation window and the
/// quick panel have no banner. A success that was read after the app was
/// launched (a resumed update) says nothing here; the page does.
class UpdateBannerLayer extends StatefulWidget {
  const UpdateBannerLayer({
    super.key,
    required this.onOpen,
    required this.child,
  });

  /// Opens the Update page.
  final VoidCallback onOpen;
  final Widget child;

  @override
  State<UpdateBannerLayer> createState() => _UpdateBannerLayerState();
}

class _UpdateBannerLayerState extends State<UpdateBannerLayer> {
  HermesUpdateRun? _run;
  bool _sawBanner = false;
  bool _readyClosed = false;
  final _childKey = GlobalKey();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final run = context.read<HermesUpdateRun>();
    if (!identical(run, _run)) {
      _run?.removeListener(_changed);
      _run = run..addListener(_changed);
      _sawBanner = run.showsBanner;
    }
  }

  void _changed() {
    final run = _run!;
    if (run.showsBanner) {
      _sawBanner = true;
      _readyClosed = false;
    } else if (run.phase != UpdatePhase.finished) {
      _sawBanner = false;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _run?.removeListener(_changed);
    super.dispose();
  }

  void _closeReady() => setState(() => _readyClosed = true);

  @override
  Widget build(BuildContext context) {
    final run = _run!;
    final version = run.postVersion ?? run.versionNow;
    final ready =
        _sawBanner &&
        !_readyClosed &&
        run.phase == UpdatePhase.finished &&
        run.result == UpdateResult.success &&
        version != null;
    final Widget? banner = run.showsBanner
        ? ServerRestartBanner.restarting(onTap: widget.onOpen)
        : ready
        ? ServerRestartBanner.ready(
            key: const ValueKey('ready'),
            version: version,
            onClose: _closeReady,
            onAutoDismiss: _closeReady,
          )
        : null;
    // The Mac window's content runs under its hidden title bar.
    final mac = platformChromeOf(context) == PlatformChrome.macos;
    // One structure with or without the banner, and the child under a global
    // key: the whole shell must keep its state when the banner comes and goes.
    return Column(
      children: [
        if (banner != null)
          Padding(
            padding: EdgeInsets.only(top: mac ? MacWindow.titlebarHeight : 0),
            child: SafeArea(bottom: false, child: banner),
          ),
        Expanded(
          // The banner took the top inset, so the page below adds none.
          child: MediaQuery.removePadding(
            context: context,
            removeTop: banner != null,
            child: KeyedSubtree(key: _childKey, child: widget.child),
          ),
        ),
      ],
    );
  }
}
