import { HermesProvider, McpInstallPanel } from "@hermes-app/ui";

const pane = {
  width: 420,
  border: "1px solid var(--h-border)",
  borderRadius: 14,
  overflow: "hidden",
} as const;

const airtable = {
  name: "airtable",
  description: "Read and write Airtable bases.",
  source: "github.com/airtable/mcp",
  transport: "remote" as const,
  auth: "API key",
  url: "https://mcp.airtable.com/mcp",
  credentials: [{ name: "AIRTABLE_API_KEY", prompt: "Personal access token" }],
};

const buildkite = {
  name: "buildkite",
  description: "Pipelines and builds.",
  transport: "command" as const,
  command: "node",
  args: ["dist/index.js", "--stdio"],
  repository: "https://github.com/buildkite/mcp-server",
  ref: "v1.2.0",
  buildSteps: ["npm ci", "npm run build"],
};

/** Needs a credential: Install stays disabled until it is filled. */
export const NeedsACredential = () => (
  <div style={pane}>
    <McpInstallPanel entry={airtable} profile="work" />
  </div>
);

/** Built on the server: the build is running. */
export const Building = () => (
  <div style={pane}>
    <McpInstallPanel entry={buildkite} profile="work" state="building" />
  </div>
);

/** Apple: the build failed, with its log. */
export const AppleFailed = () => (
  <HermesProvider platform="apple">
    <div style={pane}>
      <McpInstallPanel
        entry={buildkite}
        profile="work"
        state="failed"
        failure={{
          message: "npm ci exited with 1",
          log: [
            "npm ERR! code ERESOLVE",
            "npm ERR! Could not resolve dependency: peer typescript@5",
          ],
        }}
      />
    </div>
  </HermesProvider>
);

export const DarkFilled = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={pane}>
      <McpInstallPanel
        entry={airtable}
        profile="work"
        credentials={{ AIRTABLE_API_KEY: "patXXXXXXXXXXXX" }}
      />
    </div>
  </HermesProvider>
);
