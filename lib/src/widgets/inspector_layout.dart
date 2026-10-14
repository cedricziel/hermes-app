import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The width of an inspector on the right of a page.
const double kInspectorWidth = 380;

/// Below this width the inspector covers the page instead of sitting beside
/// it.
const double kInspectorDockedMinWidth = 760;

/// [content] with an inspector on its right, as in a Mac app: docked beside
/// the content in a wide window, over it from the right in a narrow one.
///
/// A docked inspector without content shows [placeholder]; an overlay shows
/// only once there is an [inspector]. With [onDismissOverlay], a tap beside
/// the overlay or Escape asks to close it.
class InspectorLayout extends StatelessWidget {
  const InspectorLayout({
    super.key,
    required this.content,
    required this.shown,
    this.inspector,
    this.placeholder = const SizedBox.shrink(),
    this.panelKey,
    this.onDismissOverlay,
  });

  final Widget content;

  /// Whether the inspector is on, from its toggle.
  final bool shown;
  final Widget? inspector;
  final Widget placeholder;
  final Key? panelKey;
  final VoidCallback? onDismissOverlay;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final inspector = this.inspector;
      final docked = constraints.maxWidth >= kInspectorDockedMinWidth;
      if (docked) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: content),
            if (shown)
              _Panel(
                panelKey: panelKey,
                overlay: false,
                child: inspector ?? placeholder,
              ),
          ],
        );
      }
      final dismiss = onDismissOverlay;
      final overlaid = shown && inspector != null;
      return Stack(
        children: [
          Positioned.fill(child: content),
          if (overlaid && dismiss != null)
            Positioned.fill(
              child: GestureDetector(
                key: const Key('inspector-barrier'),
                behavior: HitTestBehavior.opaque,
                onTap: dismiss,
              ),
            ),
          if (overlaid)
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              width: constraints.maxWidth < kInspectorWidth
                  ? constraints.maxWidth
                  : kInspectorWidth,
              child: _Panel(
                panelKey: panelKey,
                overlay: true,
                child: dismiss == null
                    ? inspector
                    : CallbackShortcuts(
                        bindings: {
                          const SingleActivator(LogicalKeyboardKey.escape):
                              dismiss,
                        },
                        child: Focus(autofocus: true, child: inspector),
                      ),
              ),
            ),
        ],
      );
    },
  );
}

class _Panel extends StatelessWidget {
  const _Panel({this.panelKey, required this.overlay, required this.child});

  final Key? panelKey;
  final bool overlay;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: panelKey,
      width: kInspectorWidth,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(left: BorderSide(color: theme.dividerColor)),
        boxShadow: overlay
            ? [
                BoxShadow(
                  color: theme.shadowColor.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(-4, 0),
                ),
              ]
            : null,
      ),
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}
