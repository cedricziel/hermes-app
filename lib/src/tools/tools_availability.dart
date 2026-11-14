import 'package:flutter/foundation.dart';

import '../core/safe_notifier.dart';
import '../telemetry/telemetry.dart';
import 'hermes_tools_repository.dart';
import 'tools_models.dart';
import 'tools_write.dart';

/// What one [ToolsAvailability.refresh] concluded.
enum ToolsAvailabilityRead {
  /// The list was read; its rows are the screen's first data.
  ok,

  /// The server has no tools routes.
  unsupported,

  /// The profile no longer exists. Tools is not hidden: the caller reads the
  /// profile list again.
  profileGone,

  /// The read failed. The previous answer stands.
  unreachable,

  /// A newer read, [ToolsAvailability.clear] or dispose overtook this one.
  dropped,
}

/// Whether the server offers Tools, and the rows the screen starts from.
///
/// The shell calls [refresh] with the chat's profile on connect and on
/// resume. `404` and `405` hide Tools without a message. A failed read keeps
/// the previous answer, or leaves Tools hidden when there was none, and is
/// logged as `unreachable`; no banner. The rows are seeded for the profile
/// that was read only: a screen for another profile reads its own list.
class ToolsAvailability extends ChangeNotifier with SafeNotifier {
  ToolsAvailability(
    HermesToolsRepository repository, {
    this.telemetry = const ConnectionTelemetry(),
  }) : _repository = repository;

  final HermesToolsRepository _repository;
  final ConnectionTelemetry telemetry;

  var _epoch = 0;
  var _offered = false;
  var _profileGone = false;
  String? _rowsProfile;
  var _rows = const <Toolset>[];

  /// True when the entry should show: the server answered a list, and no
  /// later read found the routes missing.
  bool get offered => _offered;

  /// True after the last read found the profile gone.
  bool get profileGone => _profileGone;

  /// The rows read for [profile]; empty when none were read for it.
  List<Toolset> rowsFor(String profile) =>
      profile == _rowsProfile ? _rows : const [];

  /// How many toolsets are on in [profile]'s last read; null when unknown.
  int? enabledCount(String profile) =>
      profile == _rowsProfile ? _rows.where((t) => t.enabled).length : null;

  Future<ToolsAvailabilityRead> refresh(String profile) async {
    final epoch = ++_epoch;
    final result = await _repository.forProfile(profile).list();
    if (disposed || epoch != _epoch) return ToolsAvailabilityRead.dropped;
    final ToolsAvailabilityRead read;
    switch (result) {
      case ToolsOk(:final value):
        _offered = true;
        _profileGone = false;
        _rows = value.toolsets;
        _rowsProfile = profile;
        read = ToolsAvailabilityRead.ok;
      case ToolsUnsupported():
        _offered = false;
        _profileGone = false;
        _rows = const [];
        _rowsProfile = null;
        read = ToolsAvailabilityRead.unsupported;
      case ToolsProfileGone():
        _profileGone = true;
        read = ToolsAvailabilityRead.profileGone;
      default:
        read = ToolsAvailabilityRead.unreachable;
    }
    quietly(
      () => telemetry.events('tools.availability', {
        'outcome': switch (read) {
          ToolsAvailabilityRead.ok => 'ok',
          ToolsAvailabilityRead.unsupported => 'unsupported',
          ToolsAvailabilityRead.profileGone => 'failed',
          _ => 'unreachable',
        },
      }),
    );
    notifyListeners();
    return read;
  }

  /// Sign-out or a server change: forgets the answer and drops reads still on
  /// their way.
  void clear() {
    _epoch++;
    _offered = false;
    _profileGone = false;
    _rows = const [];
    _rowsProfile = null;
    notifyListeners();
  }
}
