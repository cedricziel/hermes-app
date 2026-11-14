import 'dart:io';

/// Installs the pre-commit hook that runs `dart_pre_commit`.
///
/// Asks git where hooks live instead of assuming `.git/hooks`, so it also
/// works from a linked worktree (where `.git` is a file) and with
/// `core.hooksPath`. Worktrees share one hooks directory, so the hook itself
/// only relies on git running it from the top of the worktree being committed.
///
/// After a failing run the hook prints a hint about regenerating `lib/l10n/generated/`.
Future<void> main() async {
  final result = await Process.run('git', ['rev-parse', '--git-path', 'hooks']);
  if (result.exitCode != 0) {
    stderr.write(result.stderr);
    exitCode = result.exitCode;
    return;
  }

  final hooksDir = Directory((result.stdout as String).trim()).absolute;
  await hooksDir.create(recursive: true);

  final hook = File('${hooksDir.path}/pre-commit');
  await hook.writeAsString('''
#!/bin/sh
# Installed by tool/setup_git_hooks.dart.
# Git exports GIT_DIR (and friends) to hooks run from a linked worktree; the
# Flutter tool shells out to git for its own checkout and breaks on them.
unset GIT_DIR GIT_WORK_TREE
flutter pub run dart_pre_commit && exit 0
status=\$?
echo >&2 'If the errors mention lib/l10n/generated or missing AppLocalizations getters,'
echo >&2 'run `flutter pub get` (or `flutter gen-l10n`) after a pull, merge or ARB edit and commit again.'
exit \$status
''');

  if (!Platform.isWindows) {
    final chmod = await Process.run('chmod', ['a+x', hook.path]);
    if (chmod.exitCode != 0) {
      stderr.write(chmod.stderr);
      exitCode = chmod.exitCode;
      return;
    }
  }
  stdout.writeln('Installed ${hook.path}');
}
