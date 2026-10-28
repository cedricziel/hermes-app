import 'dart:async';

import 'package:flutter/material.dart';

import '../../telemetry/breadcrumbs.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/named_icon_button.dart';
import '../bot_screen_card_model.dart';
import '../bot_screen_models.dart';
import '../install/install_state.dart';

const _mono = TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.4);

/// The Bot screen card of the Activity panel: what the agent's own desktop
/// shows, who is in control, and why there is no picture when there is none.
///
/// It draws [model] and nothing else, so it needs no controller. The callbacks
/// are the actions a state offers: [onStart] (Start Screen), [onInstall]
/// (Install on Server, which also needs the model to allow it),
/// [onCopyCommand] (Copy, for the install command), [onRetry] (Try Again) and
/// [onEnlarge], whose absence hides Enlarge. [breadcrumbs] gets
/// `bot_screen.card.shown` when the state changes (never per refreshed frame),
/// `bot_screen.start.pressed` and `bot_screen.install.pressed`, with fixed
/// words only.
class BotScreenCard extends StatefulWidget {
  const BotScreenCard({
    super.key,
    required this.model,
    this.onStart,
    this.onInstall,
    this.onCopyCommand,
    this.onRetry,
    this.onEnlarge,
    this.breadcrumbs = Breadcrumbs.none,
    this.shown,
  });

  final BotScreenCardModel model;
  final VoidCallback? onStart;
  final VoidCallback? onInstall;
  final VoidCallback? onCopyCommand;
  final VoidCallback? onRetry;
  final VoidCallback? onEnlarge;
  final Breadcrumbs breadcrumbs;

  /// Remembers the state last recorded, across cards, so a card mounting
  /// again with the same state records nothing. Without it each card records
  /// its first state.
  final BotScreenShown? shown;

  @override
  State<BotScreenCard> createState() => _BotScreenCardState();
}

class _BotScreenCardState extends State<BotScreenCard> {
  var _copied = false;
  Timer? _copiedReset;

  @override
  void initState() {
    super.initState();
    _recordShown();
  }

  @override
  void didUpdateWidget(BotScreenCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.model.slug != widget.model.slug) {
      _copied = false;
      _copiedReset?.cancel();
      _recordShown();
    }
  }

  void _recordShown() {
    final slug = widget.model.slug;
    final shown = widget.shown;
    if (shown != null) {
      if (shown.slug == slug) return;
      shown.slug = slug;
    }
    widget.breadcrumbs('bot_screen.card.shown', {'state': slug});
  }

  void _start() {
    widget.breadcrumbs('bot_screen.start.pressed');
    widget.onStart?.call();
  }

  void _install() {
    widget.breadcrumbs('bot_screen.install.pressed');
    widget.onInstall?.call();
  }

  void _copy() {
    widget.onCopyCommand?.call();
    setState(() => _copied = true);
    _copiedReset?.cancel();
    _copiedReset = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  void dispose() {
    _copiedReset?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final model = widget.model;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(kHermesRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Header(),
              const SizedBox(height: 8),
              switch (model) {
                BotScreenNotOffered() => const Text(
                  "Hermes uses this server's own display.",
                ),
                BotScreenInstalling() => _InstallingBody(model.lines),
                BotScreenNotInstalled() => _notInstalled(context, model),
                BotScreenBlocked() => _blocked(context, model),
                BotScreenStarting() => const _SpinnerRow(
                  'Starting the screen…',
                ),
                BotScreenOff() => _off(context, model),
                BotScreenReadFailed() => _readFailed(),
                BotScreenShowing() => _showing(context, model),
                BotScreenControlled() => _controlled(context, model),
              },
            ],
          ),
        ),
      ),
    );
  }

  Widget _notInstalled(BuildContext context, BotScreenNotInstalled model) {
    final command = model.command;
    if (model.sandbox) {
      return const Text(
        "This profile's terminal runs in a sandbox, and its sandbox image "
        'needs the desktop stack.',
      );
    }
    final result = model.result;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (result != null) ...[
          _InstallResultNote(result),
          const SizedBox(height: 8),
        ],
        Text(
          command == null
              ? "The desktop isn't installed on the server."
              : "The desktop isn't installed on the server. Run this there:",
        ),
        if (command != null) ...[
          const SizedBox(height: 8),
          _CodeBlock(child: SelectableText(command, style: _mono)),
          if (widget.onCopyCommand != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Semantics(
                button: true,
                label: _copied ? 'Copied' : 'Copy install command',
                excludeSemantics: true,
                onTap: _copy,
                child: TextButton.icon(
                  onPressed: _copy,
                  icon: AppIcon(
                    _copied ? AppIcons.check : AppIcons.copy,
                    size: 18,
                  ),
                  label: Text(_copied ? 'Copied' : 'Copy'),
                ),
              ),
            ),
        ],
        if (model.canInstall && widget.onInstall != null) ...[
          const SizedBox(height: 8),
          _action(context, 'Install on Server', _install),
        ],
      ],
    );
  }

  Widget _blocked(BuildContext context, BotScreenBlocked model) {
    final warning = context.hermesColors.warning;
    final memory = model.memoryMb;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppIcon(AppIcons.warning, color: warning, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(model.text),
              if (memory != null)
                Text(
                  '$memory MB of memory available',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: context.hermesColors.subtleText),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _off(BuildContext context, BotScreenOff model) {
    final failure = model.startFailure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (failure != null) ...[
          Text(
            "Couldn't start the screen.",
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          Text(_failureText(failure)),
          const SizedBox(height: 8),
        ],
        const Text(
          'The screen is off. It starts by itself when Hermes needs it.',
        ),
        if (widget.onStart != null) ...[
          const SizedBox(height: 8),
          _action(context, 'Start Screen', _start),
        ],
      ],
    );
  }

  Widget _readFailed() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text("Couldn't read the screen"),
      if (widget.onRetry != null) ...[
        const SizedBox(height: 8),
        _action(context, 'Try Again', widget.onRetry!),
      ],
    ],
  );

  Widget _showing(BuildContext context, BotScreenShowing model) {
    final bytes = model.bytes;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AspectRatio(
            aspectRatio: model.aspectRatio,
            child: ColoredBox(
              color: scheme.surfaceContainerHighest,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (bytes != null)
                    Semantics(
                      image: true,
                      label: "Hermes's screen",
                      child: Image.memory(
                        bytes,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                        excludeFromSemantics: true,
                        errorBuilder: (_, _, _) => const Center(
                          child: BotScreenCaption('Picture unavailable'),
                        ),
                      ),
                    )
                  else
                    const Center(
                      child: BotScreenCaption('Waiting for the first picture…'),
                    ),
                  if (widget.onEnlarge != null)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: NamedIconButton(
                        label: 'Enlarge screen',
                        icon: AppIcons.enlarge,
                        iconSize: 18,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: widget.onEnlarge,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const BotScreenCaption('Hermes is in control'),
      ],
    );
  }

  Widget _controlled(BuildContext context, BotScreenControlled model) => Row(
    children: [
      AppIcon(AppIcons.lock, size: 18, color: context.hermesColors.subtleText),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          model.byYou ? "You're in control" : 'Someone else is in control',
        ),
      ),
    ],
  );

  Widget _action(BuildContext context, String label, VoidCallback onPressed) {
    final chrome = platformChromeOf(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: FilledButton.tonal(
        style: chrome == PlatformChrome.ios
            ? FilledButton.styleFrom(
                minimumSize: const Size(0, kAppleMinTapTarget),
              )
            : null,
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }

  static String _failureText(BotScreenFailure failure) => switch (failure) {
    BotScreenFailure.display => 'Hermes could not start it.',
    BotScreenFailure.timeout => 'Hermes did not answer in time.',
    BotScreenFailure.closed => 'The connection closed first.',
  };
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final subtle = context.hermesColors.subtleText;
    return Row(
      children: [
        AppIcon(AppIcons.screen, size: 18, color: subtle),
        const SizedBox(width: 8),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              'Bot screen',
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

/// The box the install command and the package manager's lines sit in.
class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Padding(padding: const EdgeInsets.all(10), child: child),
  );
}

/// The package manager's latest lines, each cut off after [maxLines].
class _LogLines extends StatelessWidget {
  const _LogLines(this.lines, {this.maxLines = 1});

  final List<String> lines;
  final int maxLines;

  @override
  Widget build(BuildContext context) => _CodeBlock(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          Text(
            line,
            style: _mono,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    ),
  );
}

class _InstallingBody extends StatelessWidget {
  const _InstallingBody(this.lines);

  final List<String> lines;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _SpinnerRow('Installing the desktop on the server…'),
      if (lines.isNotEmpty) ...[const SizedBox(height: 8), _LogLines(lines)],
      const SizedBox(height: 6),
      const BotScreenCaption('You can close this; the install keeps going.'),
    ],
  );
}

/// How the last install ended, when it did not succeed.
class _InstallResultNote extends StatelessWidget {
  const _InstallResultNote(this.result);

  final InstallResult result;

  @override
  Widget build(BuildContext context) {
    final error = TextStyle(color: Theme.of(context).colorScheme.error);
    return switch (result) {
      InstallRefused(:final message) => _notStarted(error, message),
      InstallUnreachable(:final failure) => _notStarted(
        error,
        _BotScreenCardState._failureText(failure),
      ),
      InstallFailed(:final lines) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('The install failed.', style: error),
          if (lines.isNotEmpty) ...[
            const SizedBox(height: 6),
            _LogLines(lines, maxLines: 3),
          ],
        ],
      ),
      InstallCancelled() => const Text('The install was cancelled.'),
      InstallNoSudo() => const Text(
        "There's no sudo on the server, so Hermes can't install the desktop "
        'itself.',
      ),
      InstallMayStillRun() => const Text(
        'The install may still be running. Check again later.',
      ),
      InstallInstalled() => const SizedBox.shrink(),
    };
  }

  Widget _notStarted(TextStyle style, String? detail) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text("Couldn't start the install.", style: style),
      if (detail != null && detail.isNotEmpty) Text(detail),
    ],
  );
}

class _SpinnerRow extends StatelessWidget {
  const _SpinnerRow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator.adaptive(strokeWidth: 2),
      ),
      const SizedBox(width: 10),
      Expanded(child: Text(text)),
    ],
  );
}

/// Small muted text under a picture, shared with the transcript preview.
class BotScreenCaption extends StatelessWidget {
  const BotScreenCaption(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: context.hermesColors.subtleText),
  );
}
