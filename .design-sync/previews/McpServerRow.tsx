import {
  GroupedListView,
  GroupedSection,
  HermesProvider,
  McpServerRow,
} from "@hermes-app/ui";
import type { ReactNode } from "react";

type Look = "iphone" | "mac" | "material";

const looks: Array<[Look, string]> = [
  ["iphone", "iPhone"],
  ["mac", "Mac"],
  ["material", "Material"],
];

const grafana = {
  name: "grafana",
  transport: "remote" as const,
  address: "https://mcp.grafana.com/mcp",
  auth: "OAuth",
  enabled: true,
};
const asana = {
  name: "asana",
  transport: "remote" as const,
  address: "https://mcp.asana.com/sse",
  auth: "OAuth",
  enabled: true,
};
const notes = {
  name: "notes-fs",
  transport: "command" as const,
  address: "npx -y @modelcontextprotocol/server-filesystem /srv/notes",
  enabled: false,
};

/** One look's frame: the provider, a 360px settings column and one inset group. */
const Group = ({
  look,
  theme = "light",
  width = 360,
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
      position: "relative",
      width,
      border: "1px solid var(--h-border)",
      borderRadius: 14,
      overflow: "hidden",
    }}
  >
    <GroupedListView device={look === "mac" ? "mac" : "touch"}>
      <GroupedSection
        dividerIndent="tile"
        footer="Changes apply from the next chat, not to one that is already running."
      >
        {children}
      </GroupedSection>
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
        <Group look={look} theme={theme} width={300}>
          {children}
        </Group>
      </div>
    ))}
  </HermesProvider>
);

const rows = (
  <>
    <McpServerRow server={grafana} test={{ ok: true, toolCount: 2 }} selected />
    <McpServerRow server={asana} test={{ signInNeeded: true }} />
    <McpServerRow server={notes} />
  </>
);

/** Tested with tools (selected), sign in needed, a command server switched off, on iPhone, Mac and Material. */
export const List = () => <Compare>{rows}</Compare>;

export const Dark = () => <Compare theme="dark">{rows}</Compare>;

/** A long name and address cut with an ellipsis, the switch disabled while the change is on its way. */
export const LongNameAndSwitching = () => (
  <Group look="iphone">
    <McpServerRow
      switching
      server={{
        name: "a-really-long-server-name-that-keeps-going-on",
        transport: "remote",
        address:
          "https://mcp.internal.example-corp.com/tenants/engineering/platform/observability/v2/streamable-http-endpoint",
        auth: "OAuth",
        enabled: true,
      }}
    />
    <McpServerRow server={grafana} />
  </Group>
);

/** iPhone: grafana swiped from the trailing edge shows Remove in red, clipped with the group. */
export const AppleSwipe = () => (
  <Group look="iphone">
    <McpServerRow
      server={grafana}
      test={{ ok: true, toolCount: 4 }}
      swipeRevealed
    />
    <McpServerRow server={notes} />
  </Group>
);

/** iPhone: a long press opens Turn off and Remove in an action sheet. */
export const AppleActionSheet = () => (
  <HermesProvider
    platform="apple"
    style={{
      position: "relative",
      width: 390,
      height: 400,
      overflow: "hidden",
      borderRadius: 14,
      border: "1px solid var(--h-border)",
    }}
  >
    <GroupedListView>
      <GroupedSection dividerIndent="tile">
        <McpServerRow server={grafana} actionSheetOpen />
        <McpServerRow server={notes} />
      </GroupedSection>
    </GroupedListView>
  </HermesProvider>
);

export const AppleSwipeDark = () => (
  <Group look="iphone" theme="dark">
    <McpServerRow server={grafana} />
    <McpServerRow server={notes} swipeRevealed />
  </Group>
);
