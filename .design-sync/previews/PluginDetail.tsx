import { HermesProvider, PluginDetail } from "@hermes-app/ui";

const pane = {
  width: 420,
  paddingTop: 16,
  border: "1px solid var(--h-border)",
  borderRadius: 14,
  overflow: "hidden",
} as const;

const netbox = {
  name: "netbox",
  version: "1.0.0",
  source: "git",
  description:
    "Query and update NetBox from the agent: look up devices, prefixes, VLANs and cables.",
  status: "enabled" as const,
  authRequired: true,
  authCommand: "hermes auth netbox",
  canUpdate: true,
  removable: true,
};

/** An installed plugin that needs a login, with Update and Remove. */
export const Installed = () => (
  <div style={pane}>
    <PluginDetail plugin={netbox} />
  </div>
);

/** A catalog entry not installed yet: what it provides, docs and Install. */
export const CatalogEntry = () => (
  <div style={pane}>
    <PluginDetail
      variant="catalog"
      plugin={{
        name: "hermes-plugin-github",
        maintainer: "Nous Research",
        official: true,
        description: "Issues, pull requests and reviews from the agent.",
        commit: "a3f9c21",
        requiresHermes: ">=0.9",
        platforms: ["linux", "macos"],
        tools: ["github_issue", "github_pr", "github_review"],
        env: ["GITHUB_TOKEN"],
        docsUrl: "https://github.com/NousResearch/hermes-plugin-github",
      }}
    />
  </div>
);

export const Apple = () => (
  <HermesProvider platform="apple">
    <div style={pane}>
      <PluginDetail
        plugin={{
          name: "gmail-triage",
          version: "0.4.2",
          source: "git",
          description: "Sort, label and draft replies in Gmail.",
          status: "disabled",
          hidden: true,
          removable: true,
        }}
      />
    </div>
  </HermesProvider>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={pane}>
      <PluginDetail plugin={netbox} busy />
    </div>
  </HermesProvider>
);
