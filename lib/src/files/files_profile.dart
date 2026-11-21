import '../surfaces/surface_snapshot.dart' show kDefaultProfile;

/// The profile the Files page of a chat reads for: the chat's own, `default`
/// for a chat that names none.
String filesProfileFor(String? chatProfile) => chatProfile ?? kDefaultProfile;
