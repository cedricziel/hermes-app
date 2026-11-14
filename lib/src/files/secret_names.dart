import 'server_path.dart';

/// Whether a file name starts with a dot, so the Files page hides it until
/// the user asks for hidden files.
bool isHidden(String name) => name.startsWith('.');

/// Which names look like they hold passwords or keys, matched without regard
/// to case. The page marks these with a lock and asks before it fetches one,
/// on every profile (Hermes skips its own check for text previews on an SSH
/// workspace). A match is a reason to ask, never proof of a secret, so it
/// leans wide: `.env.example` and `notes_token.md` match too.
abstract final class SecretNames {
  static const _exact = {
    '.envrc',
    '.netrc',
    '.npmrc',
    '.pypirc',
    '.git-credentials',
    '.htpasswd',
    '.pgpass',
    'kubeconfig',
    '_netrc',
    'auth.json',
    'auth.lock',
    '.anthropic_oauth.json',
    'id_ecdsa',
    'id_dsa',
  };

  static const _prefixes = [
    '.env.',
    '.env-',
    '.env_',
    'credentials',
    'id_rsa',
    'id_ed25519',
    'id_ecdsa',
    'id_dsa',
  ];

  static const _suffixes = [
    '.pem',
    '.ppk',
    '.key',
    '.p12',
    '.pfx',
    '.kdbx',
    '.p8',
    '.jks',
    '.keystore',
    '.ovpn',
    '.tfstate',
    '.tfvars',
  ];

  static const _fragments = ['token', 'secret', '.tfstate.'];

  /// Folders whose whole contents are treated as secret.
  static const _folders = {'.ssh', '.aws', '.gnupg', 'mcp-tokens', 'pairing'};

  /// Whether the file [name] alone looks secret.
  static bool looksSecretName(String name) {
    final lower = name.toLowerCase();
    if (lower == '.env' || _exact.contains(lower)) return true;
    if (lower.startsWith('google_') && lower.endsWith('.json')) return true;
    return _prefixes.any(lower.startsWith) ||
        _suffixes.any(lower.endsWith) ||
        _fragments.any(lower.contains);
  }

  /// Whether the file at [path] looks secret: by its own name, by sitting
  /// anywhere below `.ssh`, `.aws`, `.gnupg`, `mcp-tokens` or `pairing`, or as
  /// `.docker/config.json` or `.kube/config`.
  static bool looksSecret(ServerPath path) {
    final segments = path.segments;
    if (segments.isEmpty) return false;
    if (looksSecretName(segments.last)) return true;
    final folders = segments.sublist(0, segments.length - 1);
    if (folders.any((s) => _folders.contains(s.toLowerCase()))) return true;
    if (folders.isEmpty) return false;
    final parent = folders.last.toLowerCase();
    final name = segments.last.toLowerCase();
    return (parent == '.docker' && name == 'config.json') ||
        (parent == '.kube' && name == 'config');
  }
}
