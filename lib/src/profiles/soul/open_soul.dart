import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/hermes_repositories.dart';
import 'soul_availability.dart';
import 'soul_screen.dart';
import 'soul_telemetry.dart';

/// Whether the Personality entry points show for the connection above
/// [context]: they do until the server answers that it has no such route.
/// Without a provider (a test, the catalog) nothing is offered.
bool soulShown(BuildContext context) {
  try {
    return context.watch<SoulAvailability?>()?.shown ?? false;
  } on ProviderNotFoundException {
    return false;
  }
}

/// Pushes the Personality page of [profile]. The one place every entry point
/// (the sidebar's row, the Mac Profiles page's section) goes through. The page
/// is bound to [profile] for its whole life: the name is in every request, and
/// neither a switch of the chat's profile nor the server's active profile
/// changes it. Does nothing without a connection.
Future<void> openSoul(
  BuildContext context, {
  required String profile,
  required SoulOpenedFrom from,
}) {
  if (HermesRepositories.maybeOf(context) == null) return Future.value();
  // The root navigator, which `ConnectionPageCloser` sweeps when the
  // connection ends.
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) => SoulScreen(profile: profile, from: from),
    ),
  );
}
