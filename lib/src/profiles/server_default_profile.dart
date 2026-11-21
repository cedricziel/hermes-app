import 'hermes_profiles_repository.dart';

/// The server's own default profile by name: the profile its dashboard runs
/// for (`current`), else the sticky one (`active`); null when it names none.
String? serverDefaultProfile(ActiveProfile answer) {
  final name = answer.current.isNotEmpty ? answer.current : answer.active;
  return name.isEmpty ? null : name;
}
