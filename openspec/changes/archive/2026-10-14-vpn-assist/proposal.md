# Proposal

## Why

Many people keep their Hermes dashboard on a home server or VPS that is only reachable through Tailscale or WireGuard. Today the app gives them nothing for that: the setup screen only shows a LAN example, every connection failure reads "Could not reach <address>" whatever the cause, and after a VPN drop or a VPN that was never started the user has to notice, fix it elsewhere and tap Connect again.

## What Changes

- The setup screen and README explain the recommended VPN setup: publish the dashboard with `tailscale serve` to get an `https://<host>.<tailnet>.ts.net` address, or bind it to the VPN interface instead of `0.0.0.0`.
- A failed connection is classified (name lookup failed, refused, timed out, TLS, other) from the request error, with no plugin.
- When the failure is a lookup failure or timeout and the address looks like a VPN or private address (`*.ts.net`, `100.64.0.0/10`, RFC 1918, `.local`), the setup screen adds a hint asking whether the VPN is connected. Where the platform reports whether a VPN is active, the hint says which case applies.
- When the saved server could not be reached because of the network, the app checks again by itself after a network change or when it returns to the foreground, so turning the VPN on and switching back to the app is enough.
- New dependency `connectivity_plus`, used only as a "the network changed" signal.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `auth`: server setup gains VPN guidance, connection failures gain a classification and hint, and a network-caused failure to reach the saved server retries on a network change.

`chat` and `notifications` are unchanged. The chat socket already opens a new connection on the next send after one closed, and notifications only depend on a live socket the way they do today.

## Non-goals

- Gating or blocking a connection on VPN detection. The request to the server is always attempted.
- Detecting a VPN on iOS or macOS, where there is no reliable signal (`connectivity_plus` reports `other`, and `utun` interfaces exist without a VPN).
- Reading the Wi-Fi name (`network_info_plus`), which needs location permission.
- Starting, stopping or configuring Tailscale or WireGuard, or opening their apps.
- An internal/external address pair with automatic switching, and an embedded Tailscale node (`tsnet`). Both are future work.
- Proactively reconnecting the chat socket or the background notification path.

## Security and privacy impact

No new permission on any platform. No tokens, secure storage or preferences change. The hint is computed on the device from the address the user typed; no address leaves the device because of it. `connectivity_plus` reads the connection type only, not the network name.

## Telemetry

One log event `auth.connect.failed` on each failed connect, with attributes `reason` (`dns`, `refused`, `timeout`, `tls`, `http`, `other`), `host_kind` (`tailnet`, `private`, `local`, `public`) and `retry` (`true` for an automatic retry). It never carries the host name or address. Unchanged: telemetry stays off unless configured and failures are swallowed.

## Impact

- `lib/src/auth/auth_controller.dart`, `lib/src/screens/server_setup_screen.dart`, a new pure classifier under `lib/src/auth/`, `README.md`.
- `pubspec.yaml`: add `connectivity_plus`. The plugin brings native code on Android, iOS, macOS, Linux and Windows and no new permission (Android needs the `ACCESS_NETWORK_STATE` permission the plugin declares itself).
- `openspec/specs/auth` gains requirements when this is archived.
