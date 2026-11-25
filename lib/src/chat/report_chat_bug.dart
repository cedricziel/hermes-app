import '../telemetry/report_bug.dart';

/// [reportBug] for a chat catch-all: the chat's epoch checks (suspended,
/// cancelled, overtaken) still refuse with a `StateError`, which is not a bug,
/// so it is skipped. An `Exception` is ignored by [reportBug] as well; an
/// `Error` of any other type reaches the crash reporter.
///
/// [where] is a fixed name for the place, never text, ids or arguments.
void reportChatBug(Object error, StackTrace stack, String where) {
  if (error is StateError) return;
  reportBug(error, stack, where);
}
