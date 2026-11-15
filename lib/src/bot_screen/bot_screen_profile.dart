import '../surfaces/surface_snapshot.dart' show kDefaultProfile;

/// The profile the Bot Screen of a chat reads for: the chat's own, `default`
/// for a chat that names none. Display calls always name one.
String botScreenProfileFor(String? chatProfile) =>
    chatProfile ?? kDefaultProfile;
