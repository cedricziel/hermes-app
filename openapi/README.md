# Hermes Agent OpenAPI spec

`hermes-agent.openapi.json` is the OpenAPI 3.1 schema for the Hermes Agent
dashboard backend (`hermes_cli.web_server:app`, from
[NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent)),
which this Flutter app talks to over REST (see
`lib/src/api/hermes_api_client.dart`).

The backend serves this schema live at `/openapi.json` on a running
`hermes dashboard` instance, but that route sits behind dashboard auth on
real deployments. This copy was pulled without needing a login by installing
the `hermes-agent` package into an ephemeral virtualenv and calling
`hermes_cli.web_server.app.openapi()` directly — the same schema FastAPI
would serve, generated in-process instead of over the network.

- Source version: `hermes-agent` 0.21.3
- Regenerate with:
  ```bash
  git clone --depth 1 https://github.com/NousResearch/hermes-agent
  cd hermes-agent
  uv venv .venv-openapi && source .venv-openapi/bin/activate
  uv pip install -e .
  python -c "
  import json
  import hermes_cli.web_server as ws
  json.dump(ws.app.openapi(), open('openapi.json', 'w'), indent=2)
  "
  ```

After updating this file, regenerate `packages/hermes_api` (the generated
Dart client) from it with `../scripts/generate_hermes_api_client.sh` — see
the "The generated API client" section in the repo's top-level README.
