import '../auth/verified_session_owner.dart';

/// Retains history through expiry only with matching verified owner evidence.
class DesktopHistoryOwner {
  int? _userGeneration;
  String? _server;
  VerifiedSessionOwner? _owner;

  bool matches({
    required int userGeneration,
    required String? server,
    required VerifiedSessionOwner? owner,
  }) =>
      _userGeneration == userGeneration && _server == server && _owner == owner;

  bool update({
    required bool ready,
    required int userGeneration,
    required String? server,
    required VerifiedSessionOwner? owner,
    required bool expired,
    required VerifiedSessionOwner? expiredOwner,
  }) {
    final sameExpiry = expired && _owner != null && expiredOwner == _owner;
    final clear =
        (_userGeneration != null && _userGeneration != userGeneration) ||
        (_server != null && _server != server) ||
        (ready && _owner != owner) ||
        (!ready && !sameExpiry);
    _userGeneration = userGeneration;
    if (ready) {
      _server = server;
      _owner = owner;
    }
    return clear;
  }
}
