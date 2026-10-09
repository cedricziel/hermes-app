import {
  GroupedListView,
  GroupedSection,
  HermesProvider,
  McpCatalogRow,
} from "@hermes-app/ui";
import type { ReactNode } from "react";

type Look = "iphone" | "mac" | "material";

const looks: Array<[Look, string]> = [
  ["iphone", "iPhone"],
  ["mac", "Mac"],
  ["material", "Material"],
];

const entries = [
  {
    name: "airtable",
    description: "Read and write Airtable bases.",
    transport: "remote" as const,
    auth: "API key",
  },
  {
    name: "buildkite",
    description: "Pipelines and builds.",
    transport: "command" as const,
    auth: "No auth",
    repository: "https://github.com/buildkite/mcp-server",
  },
  {
    name: "grafana",
    description: "Dashboards and metrics.",
    transport: "remote" as const,
    auth: "OAuth",
    installed: true,
  },
];

/** One look's frame: the provider, the settings column and one inset group. */
const Group = ({
  look,
  theme = "light",
  width = 300,
  children,
}: {
  look: Look;
  theme?: "light" | "dark";
  width?: number;
  children: ReactNode;
}) => (
  <HermesProvider
    theme={theme}
    platform={look === "material" ? "material" : "apple"}
    typeRamp={look === "mac" ? "default" : undefined}
    style={{
      width,
      border: "1px solid var(--h-border)",
      borderRadius: 14,
      overflow: "hidden",
    }}
  >
    <GroupedListView device={look === "mac" ? "mac" : "touch"}>
      <GroupedSection dividerIndent="tile">{children}</GroupedSection>
    </GroupedListView>
  </HermesProvider>
);

const Compare = ({
  theme,
  children,
}: {
  theme?: "light" | "dark";
  children: ReactNode;
}) => (
  <HermesProvider
    theme={theme}
    style={{ display: "flex", gap: 12, padding: 12, alignItems: "flex-start" }}
  >
    {looks.map(([look, label]) => (
      <div key={look}>
        <div className="h-label-sm h-muted" style={{ padding: "0 4px 6px" }}>
          {label}
        </div>
        <Group look={look} theme={theme}>
          {children}
        </Group>
      </div>
    ))}
  </HermesProvider>
);

/** Remote with an API key (selected), a command entry built on the server, an installed one, on iPhone, Mac and Material. */
export const List = () => (
  <Compare>
    {entries.map((e) => (
      <McpCatalogRow key={e.name} entry={e} selected={e.name === "airtable"} />
    ))}
  </Compare>
);

/** A build running on the server, and a long description cut to one line. */
export const BuildingAndLong = () => (
  <Group look="iphone" width={390}>
    <McpCatalogRow entry={entries[1]} building />
    <McpCatalogRow
      entry={{
        name: "context7",
        description:
          "Up-to-date library docs for any package: fetches the current README, API reference and examples straight from the source instead of stale training data.",
        transport: "remote",
        auth: "No auth",
      }}
    />
  </Group>
);

export const Dark = () => (
  <Compare theme="dark">
    {entries.map((e) => (
      <McpCatalogRow key={e.name} entry={e} selected={e.name === "grafana"} />
    ))}
  </Compare>
);
