# Tasks

- [x] Classify an untrusted certificate apart from other TLS failures (`ConnectFailureKind.certificate`)
- [x] Error message and setup-screen hint per TLS failure kind and platform (`tlsHint`)
- [x] Load Android user CA certificates into the default context at launch, in background isolates and on resume (`UserCertificates`)
- [x] Tests against a loopback HTTPS server signed by a throwaway authority (`test/support/local_authority.dart`)
- [x] README section on self-signed certificates
