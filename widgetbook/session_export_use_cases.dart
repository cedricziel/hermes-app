import 'package:flutter/material.dart';
import 'package:hermes_app/src/chat/widgets/session_export_alert.dart';
import 'package:hermes_app/src/chat/widgets/session_export_failure.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

const _mb = 1024 * 1024;

/// The alert on a dimmed backdrop, at text scale [scale], optionally in
/// German. The alert is built inline, not through a route, so its width is the
/// platform's own.
Widget _alert(
  SessionExportPhase phase, {
  double scale = 1,
  bool german = false,
}) => Builder(
  builder: (context) {
    Widget child = SessionExportAlert(
      phase: phase,
      onConfirm: () {},
      onCancel: () {},
      onRetry: () {},
      onClose: () {},
    );
    if (german) {
      child = Localizations.override(
        context: context,
        locale: const Locale('de'),
        child: child,
      );
    }
    return MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: ColoredBox(
        color: Colors.black26,
        child: SizedBox.expand(child: Center(child: child)),
      ),
    );
  },
);

List<WidgetbookUseCase> _each(
  String state,
  SessionExportPhase phase, {
  double scale = 1,
  bool german = false,
}) => onEachPlatform(state, (_) => _alert(phase, scale: scale, german: german));

WidgetbookNode sessionExportAlertNode() => WidgetbookComponent(
  name: 'SessionExportAlert',
  useCases: [
    ..._each('Confirm', const SessionExportConfirm()),
    ..._each('Progress', const SessionExportProgress()),
    ..._each(
      'Progress, bytes received',
      const SessionExportProgress(receivedBytes: 12 * _mb),
    ),
    ..._each('Progress, stalled', const SessionExportProgress(stalled: true)),
    for (final kind in SessionExportFailure.values)
      ..._each(
        'Failure: ${kind.name}${kind.canRetry ? '' : ' (no Try again)'}',
        SessionExportFailed(kind),
      ),
    ..._each('Confirm, largest text', const SessionExportConfirm(), scale: 3),
    ..._each(
      'Progress, largest text',
      const SessionExportProgress(stalled: true, receivedBytes: 12 * _mb),
      scale: 3,
    ),
    ..._each(
      'Failure incomplete, largest text',
      const SessionExportFailed(SessionExportFailure.incomplete),
      scale: 3,
    ),
    ..._each('Confirm, German', const SessionExportConfirm(), german: true),
    ..._each(
      'Progress, German',
      const SessionExportProgress(stalled: true, receivedBytes: 12 * _mb),
      german: true,
    ),
    ..._each(
      'Failure incomplete, German',
      const SessionExportFailed(SessionExportFailure.incomplete),
      german: true,
    ),
    ..._each(
      'Failure profileInvalid, German',
      const SessionExportFailed(SessionExportFailure.profileInvalid),
      german: true,
    ),
  ],
);
