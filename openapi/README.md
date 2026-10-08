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

`HERMES_REF` holds the hermes-agent commit it was built from. A spec built from a source tarball has no version for Hermes to report, so `info.version` is that commit's short SHA.

To update it from Hermes main, or from a commit, branch or tag (needs `gh`, `curl` and `uv`):

```bash
scripts/fetch_openapi_spec.sh [ref]
```

The `Update Hermes contracts` workflow does this every Monday, together with the gateway contract in `openrpc/`, and opens a PR when either changed.

## The generated Dart client

The backend has around 300 routes, and hand-writing a Dio call and a model for
each one doesn't scale. `packages/hermes_api` is a `dart-dio` client generated
by [OpenAPI Generator](https://openapi-generator.tech/) from this spec, for
every route that declares a request and response schema. `HermesApiClient.raw`
(`lib/src/api/hermes_api_client.dart`) exposes it on the authenticated `Dio`
that `AuthController` manages, so new features call
`authController.api!.raw.<operation>(...)` instead of adding another hand-rolled
REST call.

`fetchStatus`, `fetchAuthProviders` and `fetchMe` stay hand-written: those
routes declare no response schema in the spec (FastAPI only emits one for a
route with a Pydantic `response_model`), so there is nothing to build a typed
model from. Many session, profile and messaging routes lack one too, which is
why their repositories parse the rows by hand.

After updating this file, regenerate the client:

```bash
./scripts/generate_hermes_api_client.sh
```

This needs a JDK (it runs `openapi-generator-cli` through `npx`) and the Dart
SDK on `PATH`. It patches a few spec constructs the `dart-dio` template can't
render (`scripts/patch_openapi_for_dart.py`) and a couple of codegen bugs in
the result (`scripts/patch_generated_dart_client.py`), then runs `pub get`,
`build_runner` and `dart analyze` inside `packages/hermes_api`. Review the diff
before committing, because a spec change can rename or retype generated
methods. Never edit `packages/hermes_api` by hand: fix template bugs in the
patch scripts.

`.github/workflows/verify-hermes-api-client.yml` runs the same script in CI and
fails if it produces a diff, so a spec update without a regenerated client is
caught instead of silently drifting. `packages/hermes_api/pubspec.lock` is
committed on purpose, so that check isn't at the mercy of a transitive
dependency picking up a new version between two runs.
