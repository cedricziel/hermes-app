# Proposal

## Why

A dashboard behind a reverse proxy with a certificate from the user's own authority (Caddy's `tls internal`, a home CA) cannot be reached (#792). The setup screen shows "Could not reach …" or the raw handshake error, which does not say that the certificate is the problem or how to fix it. On Android the fix the browser accepts, installing the authority's root as a user CA certificate, does not help either: Dart reads only the system store there.

## What Changes

- A handshake that fails because the certificate is not trusted (`CERTIFICATE_VERIFY_FAILED`, or Dio's `badCertificate`) is classified as a certificate failure, apart from other TLS failures such as `https://` sent to a plain HTTP port.
- The error message says so: "This device doesn't trust the server's certificate." Another TLS failure says "The secure connection to the server failed."
- The setup screen adds a hint for either: for a certificate, how to trust a root on this platform (iOS profile plus Certificate Trust Settings, macOS Keychain Access, Android CA certificate) or to use a publicly trusted certificate; for other TLS failures, to check `http://` against `https://` and the port.
- On Android, the CA certificates the user installed are added to Dart's default security context at launch, in every background isolate, and again when the app resumes, through the `flutter_user_certificates_android` plugin.
- The README's connection section explains self-signed certificates.

Non-goals:

- No "trust this certificate anyway" or certificate pinning in the app: sign-in runs in the system browser, which would still reject the certificate.
- No change on iOS and macOS beyond the message: Dart verifies against the system's trust settings there, so a trusted root already works.

Security and privacy impact:

- On Android the app trusts user-installed CA certificates, as Chrome does. A CA a user or their device management installed can then read the app's traffic, as it can the browser's. That matches what the sign-in browser already accepts.
- No certificate, address or host name is logged; `auth.connect.failed` gains the reason `certificate`.
