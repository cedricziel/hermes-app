## ADDED Requirements

### Requirement: Failed connections are classified

The system SHALL classify a failure to reach the server, from the error the request produced, as one of: name lookup failed, connection refused, timed out, TLS failure, an HTTP error answer, or other. The classification SHALL NOT depend on any platform plugin and SHALL NOT change the error message already specified for the failure. It SHALL apply to the status request, the providers request and the stored-session check.

#### Scenario: Host name does not resolve

- **WHEN** the status request fails because the host name cannot be resolved
- **THEN** the failure is classified as name lookup failed

#### Scenario: Nothing listens on the port

- **WHEN** the status request fails because the host answered that the connection was refused
- **THEN** the failure is classified as connection refused

#### Scenario: Host does not answer

- **WHEN** the status request runs into its connect or receive timeout
- **THEN** the failure is classified as timed out

#### Scenario: Certificate is rejected

- **WHEN** the status request to an `https` address fails during the TLS handshake
- **THEN** the failure is classified as a TLS failure

### Requirement: VPN hint on the setup screen

When a connect fails and the failure is name lookup failed or timed out, and the server address is one that is normally reachable only over a VPN or a local network, the setup screen SHALL show a hint below the error message asking whether the VPN is connected. Such addresses are hosts ending in `.ts.net`, IPv4 addresses in `100.64.0.0/10` or in the private ranges `10.0.0.0/8`, `172.16.0.0/12` and `192.168.0.0/16`, and hosts ending in `.local`. Where the platform reports whether a VPN is active, the hint SHALL say so: that no VPN is active on this device, or that a VPN is active but the server did not answer through it. Where it does not, the hint SHALL be the question alone. A connection refused failure to such an address SHALL instead be hinted as "The server answered, but nothing is listening at that address. Check that the dashboard is running and bound to it." No hint SHALL be shown for other failures or other addresses. The system SHALL NOT decide whether to attempt a connection from whether a VPN is active.

#### Scenario: Tailnet name times out

- **WHEN** a connect to `http://box.tail1234.ts.net:9119` times out
- **THEN** the error message is "Could not reach http://box.tail1234.ts.net:9119"
- **AND** a hint asks whether the VPN is connected

#### Scenario: Tailscale address on a platform that reports VPN state, none active

- **WHEN** a connect to `http://100.101.102.103:9119` times out
- **AND** the platform reports that no VPN is active
- **THEN** the hint says that no VPN is active on this device

#### Scenario: VPN active but the server does not answer

- **WHEN** a connect to a private address times out
- **AND** the platform reports that a VPN is active
- **THEN** the hint says that a VPN is active but the server did not answer through it

#### Scenario: Refused on a VPN address

- **WHEN** a connect to `http://100.101.102.103:9119` is refused
- **THEN** the hint says nothing listens at that address and to check that the dashboard is running and bound to it

#### Scenario: Public host gets no hint

- **WHEN** a connect to `https://hermes.example.com` times out
- **THEN** the error message is shown and no VPN hint is shown

#### Scenario: Connect is attempted without a VPN

- **WHEN** the user submits an address and the platform reports that no VPN is active
- **THEN** the status request is still sent

### Requirement: Setup screen explains reaching the server over a VPN

The server setup screen SHALL tell the user, in a short text with a link to the README section, that a dashboard reachable only through Tailscale or WireGuard can be entered by its VPN address, and that `tailscale serve` gives an `https://` address with a certificate. The README SHALL describe both, and SHALL advise starting the dashboard bound to the VPN interface address rather than to all interfaces.

#### Scenario: Setup screen shows the VPN note

- **WHEN** the setup screen is shown
- **THEN** it includes the note about reaching a dashboard over Tailscale or WireGuard

### Requirement: Saved server is checked again after a network change

While the state is connection error because the saved server could not be reached (name lookup failed, connection refused, timed out or a network error), the system SHALL connect to the saved address again, as a restoring connect, when the network changes and when the app returns to the foreground. Network changes SHALL be debounced so that several changes in quick succession cause one attempt. The system SHALL NOT retry after a failure that is not a network failure (an HTTP error answer, a malformed response or a TLS failure), when there is no saved address, or while a connect is in flight, and SHALL NOT retry the address the user just typed and submitted until that connect has finished. A retry that succeeds SHALL continue as any connect does, including opening the app when the session is valid.

#### Scenario: VPN comes up

- **WHEN** the saved server could not be reached because it timed out
- **AND** the network changes because the VPN connected
- **THEN** the app connects to the saved address again
- **AND** when the server answers and the session is valid, the app opens

#### Scenario: Returning to the app

- **WHEN** the saved server could not be reached and the app returns to the foreground
- **THEN** the app connects to the saved address again

#### Scenario: Burst of network changes

- **WHEN** the network reports several changes within a second
- **THEN** one connect attempt is made

#### Scenario: Server answered with an error

- **WHEN** the connection error came from an HTTP error answer or a malformed response
- **AND** the network changes
- **THEN** no connect is attempted

#### Scenario: A retry fails

- **WHEN** an automatic retry fails
- **THEN** the state stays connection error and the message and hint are refreshed for the new failure
