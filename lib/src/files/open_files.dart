import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../api/hermes_repositories.dart';
import '../chat/chat_controller.dart';
import '../chat/media/media_store.dart';
import '../surfaces/surface_snapshot.dart' show kDefaultProfile;
import '../telemetry/breadcrumbs.dart';
import 'files_availability.dart';
import 'files_platform_policy.dart';
import 'files_screen.dart';
import 'files_telemetry.dart';
import 'hermes_files_repository.dart';
import 'server_path.dart';

/// Whether the Files entry points show for the connection above [context]:
/// the server has `/api/fs`. Starts the probe the first time it is read.
bool filesShown(BuildContext context) {
  try {
    final availability = context.watch<FilesAvailability?>();
    availability?.ensureProbed();
    return availability?.shown ?? false;
  } on ProviderNotFoundException {
    return false;
  }
}

/// Opens the Files page of the selected chat of [chat]. The one place every
/// entry point (the Activity panel's row, the chat's menu, View > Show
/// Files) goes through. Does nothing without a chat, a connection or a
/// media store.
Future<void> openFiles(
  BuildContext context,
  ChatController chat, {
  FilesOpenedFrom from = FilesOpenedFrom.activity,
}) async {
  final thread = chat.selectedThread;
  final repositories = HermesRepositories.maybeOf(context);
  final media = context.read<MediaStore?>();
  if (thread == null || repositories == null || media == null) return;
  Breadcrumbs breadcrumbs;
  try {
    breadcrumbs = context.read<Breadcrumbs>();
  } on ProviderNotFoundException {
    breadcrumbs = Breadcrumbs.none;
  }
  final profile = chat.profile ?? kDefaultProfile;
  final threadId = thread.id;
  final telemetry = FilesTelemetry(repositories.telemetry, breadcrumbs);
  final cwd = thread.workingDirectory;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => FilesScreen(
        source: HermesFilesRepository(
          repositories.api,
          profile: profile,
          telemetry: telemetry,
        ),
        media: media,
        profile: profile,
        cwd: cwd == null ? null : ServerPath.tryParse(cwd),
        from: from,
        telemetry: telemetry,
        closeWhen: chat,
        shouldClose: () =>
            chat.selectedId != threadId ||
            (chat.profile ?? kDefaultProfile) != profile,
        share: _canShare ? _share : null,
        policy: FilesPlatformPolicy(),
      ),
    ),
  );
}

bool get _canShare =>
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.android;

Future<void> _share(File file, Rect? origin) => SharePlus.instance.share(
  ShareParams(files: [XFile(file.path)], sharePositionOrigin: origin),
);
