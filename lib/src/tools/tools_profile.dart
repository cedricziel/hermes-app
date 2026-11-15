import 'tools_availability.dart';

/// The profile the Tools screen opens for: the chat's own, else the one the
/// list was last asked for. A chat on the server's default profile names none.
String? toolsProfileFor(String? chatProfile, ToolsAvailability? availability) =>
    chatProfile ?? availability?.requestedProfile ?? availability?.profile;
