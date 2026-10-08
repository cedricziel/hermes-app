import 'package:hermes_api/hermes_api.dart';

import '../api/session_source.dart';

/// What Hermes tells the agent about where this app's replies appear. Hermes
/// has no hint of its own for [gatewaySessionSource], so without it the
/// agent knows nothing of the screen it writes for. It names only what the
/// transcript renders.
const appPlatformHint =
    'The user reads your replies in the Hermes app on their phone or '
    'computer, a graphical chat that may be as narrow as a phone screen. '
    'Markdown renders: headings, lists, tables, links and fenced code '
    'blocks. To hand over a file, write MEDIA:/absolute/path/to/file on its '
    'own: images show in the chat, any other file becomes an attachment the '
    'user can download. A local image in Markdown image syntax does not '
    'show; use MEDIA: for it. There are no inline HTML previews or widgets.';

/// Every hint text an earlier version of the app wrote. A profile that still
/// holds one of them is offered [appPlatformHint] in its place; any other
/// text was written by someone else and is left alone. Add the old text here
/// whenever [appPlatformHint] changes.
const earlierAppPlatformHints = <String>[];

/// Where a profile stands with the app's hint.
enum PlatformHintState {
  /// No `platform_hints.hermes_app` is saved.
  missing,

  /// It holds a text an earlier app wrote.
  outdated,

  /// It holds the current text.
  current,

  /// Someone else set it; the app never touches it.
  foreign,
}

/// Reads and writes the app's entry in a profile's `platform_hints`, which
/// Hermes reads when it builds a session.
class PlatformHintRepository {
  PlatformHintRepository(
    this._api, {
    this.text = appPlatformHint,
    this.earlierTexts = earlierAppPlatformHints,
  });

  final DefaultApi _api;
  final String text;
  final List<String> earlierTexts;

  /// Where [profile] stands, from its saved config only (defaults left out).
  /// Null when the config cannot be read.
  Future<PlatformHintState?> state(String profile) async {
    try {
      final response = await _api.getConfigApiConfigGet(
        profile: profile,
        includeDefaults: false,
      );
      final data = response.data;
      if (data is! Map) return null;
      final hints = data['platform_hints'];
      return switch (hints is Map ? hints[gatewaySessionSource] : null) {
        null => PlatformHintState.missing,
        {'replace': final String saved} when saved == text =>
          PlatformHintState.current,
        {'replace': final String saved} && final Map entry
            when entry.length == 1 && earlierTexts.contains(saved) =>
          PlatformHintState.outdated,
        _ => PlatformHintState.foreign,
      };
    } on Object {
      return null;
    }
  }

  /// Saves the current text for [profile]. Hermes merges the body into the
  /// file, so nothing else in the config changes.
  Future<void> write(String profile) => _api.updateConfigApiConfigPut(
    profile: profile,
    configUpdate: ConfigUpdate(
      config: {
        'platform_hints': {
          gatewaySessionSource: {'replace': text},
        },
      },
    ),
  );
}
