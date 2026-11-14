import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/files/secret_names.dart';
import 'package:hermes_app/src/files/server_path.dart';

bool secret(String path) => SecretNames.looksSecret(ServerPath.tryParse(path)!);

void main() {
  test('every name the spec lists looks secret, in any letter case', () {
    const names = [
      '.env',
      '.env.local',
      '.envrc',
      '.netrc',
      '.npmrc',
      '.pypirc',
      '.git-credentials',
      'credentials.json',
      'credentials',
      'key.pem',
      'a.key',
      'a.p12',
      'a.pfx',
      'id_rsa',
      'id_rsa.pub',
      'id_ed25519',
      'vault.kdbx',
      'api_token.txt',
      'my-secret.yaml',
      '.htpasswd',
      '.pgpass',
      'AuthKey.p8',
      'release.jks',
      'upload.keystore',
      'office.ovpn',
      'terraform.tfstate',
      'terraform.tfstate.backup',
      'prod.tfvars',
      'kubeconfig',
    ];
    for (final name in names) {
      expect(SecretNames.looksSecretName(name), isTrue, reason: name);
      expect(SecretNames.looksSecretName(name.toUpperCase()), isTrue);
      expect(secret('/srv/p/$name'), isTrue, reason: name);
    }
  });

  test('ordinary names do not', () {
    for (final name in [
      'notes.md',
      'environment.py',
      'envelope.txt',
      'app.py',
      'monkey.dart',
      'keyboard.txt',
      'README',
      'config.json',
    ]) {
      expect(SecretNames.looksSecretName(name), isFalse, reason: name);
    }
  });

  test('anything below a secret folder does, at any depth', () {
    expect(secret('/home/me/.ssh/known_hosts'), isTrue);
    expect(secret('/home/me/.SSH/config'), isTrue);
    expect(secret('/home/me/.aws/config'), isTrue);
    expect(secret('/home/me/.gnupg/a/b/c.txt'), isTrue);
    expect(secret('/srv/mcp-tokens/x.json'), isTrue);
    expect(secret('/srv/p/ssh/readme.txt'), isFalse);
  });

  test('config.json is secret only inside .docker', () {
    expect(secret('/home/me/.docker/config.json'), isTrue);
    expect(secret('/home/me/.Docker/Config.JSON'), isTrue);
    expect(secret('/home/me/.docker/other.json'), isFalse);
    expect(secret('/home/me/app/config.json'), isFalse);
  });

  test('a root is not a file', () {
    expect(SecretNames.looksSecret(ServerPath.tryParse('/')!), isFalse);
  });

  test('isHidden is a leading dot', () {
    expect(isHidden('.gitignore'), isTrue);
    expect(isHidden('notes.md'), isFalse);
    expect(isHidden('a.b'), isFalse);
  });
}
