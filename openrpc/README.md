# Hermes gateway contract

`hermes-gateway.openrpc.json` describes the JSON-RPC protocol of the dashboard's `/api/ws` socket, which the chat uses. It lists every RPC method, every event frame the server sends (`x-notifications`) and every request the server sends to the client (`x-server-requests`), each with its payload schema. Hermes generates it from `tui_gateway/contracts/` (`apps/shared/src/gateway-contract.openrpc.json` in [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent)). `HERMES_REF` holds the commit it was copied from.

`test/gateway/gateway_contract_test.dart` says, for each event frame and server request, what the app does with it: shows it, uses it inside the transport, doesn't show it yet, or has no use for it. The test fails when the contract lists a frame the table doesn't have.

To update the contract:

```bash
scripts/fetch_gateway_contract.sh          # Hermes main
scripts/fetch_gateway_contract.sh <ref>    # a commit, branch or tag
flutter test test/gateway/gateway_contract_test.dart
```

Then add each new frame to the test's table, with a reason.
