import 'package:flutter/material.dart';

/// What each Plugins tab says when a reload failed.
const kInstalledRefreshFailed = 'Could not refresh plugins';
const kCatalogRefreshFailed = 'Could not refresh the catalog';
const kProvidersRefreshFailed = 'Could not refresh provider settings';

/// Runs [refresh] and, when it reports a failure, shows [failure] on
/// [messenger]. Pull to refresh, the Mac toolbar button and View > Reload all
/// go through it.
Future<void> refreshReporting(
  ScaffoldMessengerState messenger,
  Future<bool> Function() refresh,
  String failure,
) async {
  if (!await refresh()) {
    messenger.showSnackBar(SnackBar(content: Text(failure)));
  }
}
