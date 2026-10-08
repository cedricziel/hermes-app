import 'dart:async';

import 'package:flutter/material.dart';

import '../widgets/adaptive_sheet.dart';
import 'platform_hint_offer.dart';
import 'widgets/platform_hint_prompt.dart';

/// Asks about [offer] in a dialog on a wide layout and a bottom sheet on a
/// compact one. It stays open while the hint is saved and after a failed
/// save; closing it any other way counts as "not now".
Future<void> showPlatformHintPrompt(
  BuildContext context,
  PlatformHintOffer offer,
) async {
  offer.offered();
  await showAdaptiveSheet<void>(
    context,
    builder: (route) => ListenableBuilder(
      listenable: offer,
      builder: (context, _) => PopScope(
        canPop: !offer.busy,
        child: PlatformHintPrompt(
          profiles: offer.profiles,
          selected: offer.selected,
          onToggle: offer.toggle,
          text: offer.repository.text,
          update: offer.update,
          busy: offer.busy,
          failed: offer.failed,
          saved: offer.saved,
          onAdd: () async {
            if (await offer.add() && route.mounted) Navigator.of(route).pop();
          },
          onLater: () {
            offer.later();
            Navigator.of(route).pop();
          },
          onNever: () {
            unawaited(offer.never());
            Navigator.of(route).pop();
          },
        ),
      ),
    ),
  );
  offer.later();
}
