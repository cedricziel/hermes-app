/// Whether a 404 body says the profile is gone, not the route.
///
/// Hermes answers a request for a profile it does not have with the detail
/// `Profile 'NAME' does not exist.`; a route an older server lacks answers
/// `No such API endpoint: ...` (or `{"error": ...}`). A 404 with any other
/// detail, or no detail, is therefore not a missing profile.
bool namesMissingProfile(Object? body) =>
    body is Map &&
    body['detail'] is String &&
    (body['detail'] as String).startsWith("Profile '");
