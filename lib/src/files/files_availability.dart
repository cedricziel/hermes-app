import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/hermes_repositories.dart';
import '../telemetry/breadcrumbs.dart';
import 'files_failure.dart';
import 'files_models.dart';
import 'files_telemetry.dart';
import 'hermes_files_repository.dart';

/// Whether the connected server has the `/api/fs` routes.
enum FilesSupport {
  /// The probe has not answered yet: nothing is offered.
  unknown,

  /// The routes exist, or the probe failed for another reason: a failure
  /// is not "unsupported", so the entry points show and the page explains.
  supported,

  /// 404 or 405: an older Hermes. No row, no menu item, no error.
  unsupported,
}

/// What a connection's first `default-cwd` said about Files, kept for the
/// connection: a new one is made for each API client, so a server change or
/// a new sign-in asks again. The probe goes without `profile`, and the folder
/// it answers is thrown away.
class FilesAvailability extends ChangeNotifier {
  FilesAvailability(this._probe, {this.connection});

  /// Probes through [repositories]'s API client.
  factory FilesAvailability.forRepositories(
    HermesRepositories repositories, {
    Breadcrumbs breadcrumbs = Breadcrumbs.none,
  }) {
    final files = HermesFilesRepository(
      repositories.api,
      telemetry: FilesTelemetry(repositories.telemetry, breadcrumbs),
    );
    return FilesAvailability(() => files.probe(), connection: repositories.api);
  }

  final Future<FilesResult<void>> Function() _probe;

  /// What this answer is for: the API client of the connection. A new
  /// client is a new connection and asks again.
  final Object? connection;
  var _support = FilesSupport.unknown;
  var _started = false;
  var _disposed = false;

  FilesSupport get support => _support;

  /// Whether the Files row, menu item and menu command are shown.
  bool get shown => _support == FilesSupport.supported;

  /// Starts the probe, the first time only.
  void ensureProbed() {
    if (_started) return;
    _started = true;
    unawaited(_run());
  }

  Future<void> _run() async {
    FilesSupport result;
    try {
      result =
          await _probe().timeout(
            const Duration(seconds: 10),
            onTimeout: () => const FilesFailed(FilesFailure.unreachable),
          ) is FilesUnsupported
          ? FilesSupport.unsupported
          : FilesSupport.supported;
    } on Object {
      result = FilesSupport.supported;
    }
    if (_disposed) return;
    _support = result;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    super.dispose();
  }
}
