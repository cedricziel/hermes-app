import 'package:flutter/foundation.dart';

import 'agent_models.dart';
import 'subagent_roster.dart';

/// Which agent's detail the Activity panel shows, if any. It holds the
/// [AgentKey] chosen when the user picked the agent, so a list that refreshes
/// or reorders never moves the selection, or a stop, to another agent.
///
/// One lives with each window's chat screen; it is cleared when the chat or
/// the profile changes and when the panel closes.
class ActivitySelection extends ChangeNotifier {
  AgentKey? _key;
  var _stopRequested = false;
  var _source = 'panel';

  AgentKey? get key => _key;

  /// The agent was picked by "Stop agent" on its row: the detail opens with
  /// the confirmation.
  bool get stopRequested => _stopRequested;

  /// Where the selection came from: `panel` or `transcript`.
  String get source => _source;

  void select(AgentKey key, {String source = 'panel', bool stop = false}) {
    if (_key == key && _stopRequested == stop && _source == source) return;
    _key = key;
    _source = source;
    _stopRequested = stop;
    notifyListeners();
  }

  void clear() {
    if (_key == null) return;
    _key = null;
    _stopRequested = false;
    notifyListeners();
  }

  @override
  String toString() => 'ActivitySelection(${_key == null ? 'none' : 'agent'})';
}

/// The key of [subagentId] in [roster]'s chat, as the user picks it: the chat,
/// its profile, the connection now and the agent.
AgentKey agentKeyOf(SubagentRoster roster, String subagentId) => AgentKey(
  threadId: roster.threadId,
  profile: roster.profile,
  connection: roster.connection ?? roster,
  subagentId: subagentId,
);
