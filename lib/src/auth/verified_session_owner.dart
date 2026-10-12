import '../models/hermes_session.dart';

class VerifiedSessionOwner {
  const VerifiedSessionOwner({
    required this.server,
    required this.user,
    required this.organization,
    required this.provider,
  });

  static VerifiedSessionOwner? fromIdentity(
    String server,
    HermesIdentity identity,
  ) => identity.userId.trim().isEmpty
      ? null
      : VerifiedSessionOwner(
          server: server,
          user: identity.userId,
          organization: identity.orgId,
          provider: identity.provider,
        );

  final String server;
  final String user;
  final String organization;
  final String provider;

  @override
  bool operator ==(Object other) =>
      other is VerifiedSessionOwner &&
      server == other.server &&
      user == other.user &&
      organization == other.organization &&
      provider == other.provider;

  @override
  int get hashCode => Object.hash(server, user, organization, provider);
}
