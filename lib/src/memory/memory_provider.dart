/// How the memory provider the profile is set to stands, from
/// `GET /api/memory`. `missing` is a provider the config names that is no
/// longer installed on the server.
enum MemoryProviderState {
  builtin('builtin'),
  ready('ready'),
  needsConfig('needs_config'),
  unavailable('unavailable'),
  missing('missing');

  const MemoryProviderState(this.wire);

  /// The slug telemetry carries: the server's own word for the status.
  final String wire;
}

class MemoryProviderStatus {
  const MemoryProviderStatus(this.state, {this.name, this.description});

  static const builtin = MemoryProviderStatus(MemoryProviderState.builtin);

  final MemoryProviderState state;

  /// The active provider's name; null for the built-in files.
  final String? name;
  final String? description;
}

/// Which memory files `POST /api/memory/reset` deletes.
enum MemoryResetTarget {
  agentNotes('memory', 'agent notes'),
  aboutYou('user', 'about you'),
  both('all', 'agent notes and about you');

  const MemoryResetTarget(this.wire, this.what);

  /// The request's `target`, also the slug telemetry carries.
  final String wire;
  final String what;
}

enum MemoryNoticeTone { success, warning, error }

/// What the screen says about the last reset.
class MemoryNotice {
  const MemoryNotice(this.text, this.tone);
  final String text;
  final MemoryNoticeTone tone;
}
