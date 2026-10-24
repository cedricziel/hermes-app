import 'dart:io';
import 'dart:typed_data';

/// A certificate authority of its own, like Caddy's `tls internal`, and an
/// HTTPS server on loopback whose certificate it signed. Made with `openssl`
/// for each run, so the leaf stays within the validity Apple's verifier
/// accepts.
class LocalAuthority {
  LocalAuthority._(this._dir, this.server, this.rootDer);

  static Future<LocalAuthority> start() async {
    final dir = await Directory.systemTemp.createTemp('hermes_tls');
    Future<void> openssl(List<String> args) async {
      final result = await Process.run(
        'openssl',
        args,
        workingDirectory: dir.path,
      );
      if (result.exitCode != 0) {
        throw StateError('openssl ${args.first} failed: ${result.stderr}');
      }
    }

    File('${dir.path}/leaf.ext').writeAsStringSync(
      'subjectAltName=IP:127.0.0.1\n'
      'extendedKeyUsage=serverAuth\n'
      'basicConstraints=critical,CA:FALSE\n',
    );
    await openssl([
      'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '30', //
      '-subj', '/CN=Hermes Test Local Authority',
      '-addext', 'basicConstraints=critical,CA:TRUE',
      '-addext', 'keyUsage=critical,keyCertSign,cRLSign',
      '-keyout', 'root.key', '-out', 'root.pem',
    ]);
    await openssl([
      'req', '-new', '-newkey', 'rsa:2048', '-nodes', //
      '-subj', '/CN=127.0.0.1', '-keyout', 'leaf.key', '-out', 'leaf.csr',
    ]);
    await openssl([
      'x509', '-req', '-in', 'leaf.csr', '-days', '30', //
      '-CA', 'root.pem', '-CAkey', 'root.key', '-CAcreateserial',
      '-extfile', 'leaf.ext', '-out', 'leaf.pem',
    ]);
    await openssl([
      'x509',
      '-in',
      'root.pem',
      '-outform',
      'DER',
      '-out',
      'root.der',
    ]);

    final context = SecurityContext()
      ..useCertificateChain('${dir.path}/leaf.pem')
      ..usePrivateKey('${dir.path}/leaf.key');
    final server = await HttpServer.bindSecure(
      InternetAddress.loopbackIPv4,
      0,
      context,
    );
    server.listen((request) => request.response.close());
    return LocalAuthority._(
      dir,
      server,
      File('${dir.path}/root.der').readAsBytesSync(),
    );
  }

  final Directory _dir;
  final HttpServer server;

  /// The authority's root as DER, as Android's CA store hands it over.
  final Uint8List rootDer;

  Uri get url => Uri.parse('https://127.0.0.1:${server.port}');

  Future<void> close() async {
    await server.close(force: true);
    await _dir.delete(recursive: true);
  }
}
