## MODIFIED Requirements

### Requirement: Failed connections are classified

The system SHALL classify a failure to reach the server, from the error the request produced, as one of: name lookup failed, connection refused, timed out, certificate not trusted, another TLS failure, an HTTP error answer, or other. The classification SHALL NOT depend on any platform plugin. It SHALL NOT change the error message already specified for the failure, except that a certificate failure SHALL read "This device doesn't trust the server's certificate." and another TLS failure "The secure connection to the server failed." It SHALL apply to the status request, the providers request and the stored-session check.

#### Scenario: Host name does not resolve

- **WHEN** the status request fails because the host name cannot be resolved
- **THEN** the failure is classified as name lookup failed

#### Scenario: Nothing listens on the port

- **WHEN** the status request fails because the host answered that the connection was refused
- **THEN** the failure is classified as connection refused

#### Scenario: Host does not answer

- **WHEN** the status request runs into its connect or receive timeout, or the network reports the host or network as unreachable
- **THEN** the failure is classified as timed out

#### Scenario: Certificate is rejected

- **WHEN** the status request to an `https` address fails during the TLS handshake because the device does not trust the server's certificate
- **THEN** the failure is classified as certificate not trusted
- **AND** the error message is "This device doesn't trust the server's certificate."

#### Scenario: HTTPS to a plain HTTP port

- **WHEN** the status request to an `https` address fails during the TLS handshake for another reason, such as a port that speaks plain HTTP
- **THEN** the failure is classified as another TLS failure
- **AND** the error message is "The secure connection to the server failed."

## ADDED Requirements

### Requirement: TLS hint on the setup screen

When a connect fails because the certificate is not trusted, the setup screen SHALL show a hint below the error message, for any address, saying that a certificate from the user's own authority (such as Caddy's `tls internal`) works once this device trusts the authority's root, how to do that on the platform (iOS: install the root as a profile and turn on full trust in Certificate Trust Settings; macOS: add it to the System keychain and set it to Always Trust; Android: install it as a CA certificate in Settings), and that a certificate from a public authority needs none of this. When a connect fails with another TLS failure, the hint SHALL ask the user to check whether the address should start with `http://` or `https://` and whether the port serves it. A TLS hint replaces the VPN hint.

#### Scenario: Caddy with tls internal

- **WHEN** a connect to `https://hermes.lan:8443` fails because the certificate is not trusted
- **THEN** the hint explains how to trust the authority's root on this platform

#### Scenario: https to the dashboard's own port

- **WHEN** a connect to `https://192.168.1.2:9119` fails because the port speaks plain HTTP
- **THEN** the hint asks to check `http://` against `https://` and the port

### Requirement: Android trusts user-installed authorities

On Android the system SHALL add the CA certificates the user installed to the trust store Dart uses for every request and websocket, at launch before the first connect, in each background isolate before it talks to Hermes, and again when the app returns to the foreground. A certificate that cannot be read SHALL be skipped and SHALL NOT keep the app from starting. A certificate the user removes MAY stay trusted until the app process ends, since Dart cannot remove a trusted certificate from a context. Other platforms SHALL NOT change their trust store.

#### Scenario: Root installed after a failed connect

- **WHEN** a connect fails because the certificate is not trusted
- **AND** the user installs the authority's root as a CA certificate in Settings and returns to the app
- **THEN** the next connect to the address succeeds
