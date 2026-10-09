import { GroupedListView, GroupedRow, GroupedSection, GroupedTile, HermesProvider, Spinner } from "@hermes-app/ui";
import type { ReactNode } from "react";

type Look = "iphone" | "mac" | "material";

const frame = {
  width: 264,
  border: "1px solid var(--h-border)",
  borderRadius: 14,
  overflow: "hidden",
} as const;

/** iPhone, Mac and Material panels side by side, each a `GroupedListView`. */
const Compare = ({
  theme = "light",
  children,
}: {
  theme?: "light" | "dark";
  children: (look: Look) => ReactNode;
}) => (
  <HermesProvider
    theme={theme}
    style={{ display: "flex", gap: 12, padding: 12, alignItems: "flex-start" }}
  >
    {(["iphone", "mac", "material"] as const).map((look) => (
      <HermesProvider
        key={look}
        theme={theme}
        platform={look === "material" ? "material" : "apple"}
        typeRamp={look === "mac" ? "default" : undefined}
        style={frame}
      >
        <GroupedListView device={look === "mac" ? "mac" : "touch"}>
          {children(look)}
        </GroupedListView>
      </HermesProvider>
    ))}
  </HermesProvider>
);

const noop = () => {};

/** Every line a row can draw: inline meta, a mono subtitle, a caption, a warning and an error, a value with the chevron, a leading icon, a trailing spinner. */
export const Lines = () => (
  <Compare>
    {() => (
      <GroupedSection dividerIndent="leading">
        <GroupedRow
          icon="extension"
          title="netbox"
          meta="v1.2.0"
          subtitle="Query NetBox for devices and prefixes."
          value="On"
          onClick={noop}
        />
        <GroupedRow
          icon="terminal"
          title="filesystem"
          subtitle="npx -y @acme/mcp-fs ~/notes"
          monospaceSubtitle
          caption="Command · 4 tools"
          onClick={noop}
        />
        <GroupedRow
          icon="smart_toy"
          title="Discord"
          error="Invalid bot token"
          warning="Messages will not arrive"
        />
        <GroupedRow icon="sync" title="Checking the server" trailing={<Spinner size={18} />} />
      </GroupedSection>
    )}
  </Compare>
);

/** A selected row (the one shown beside the list), a value without a chevron, a disabled row and a destructive "Remove plugin" row in its own group. */
export const States = () => (
  <Compare>
    {(look) => (
      <>
        <GroupedSection dividerIndent="tile">
          <GroupedRow
            leading={<GroupedTile>N</GroupedTile>}
            title="notes-sync"
            subtitle="Keep a folder of notes in step with memory."
            selected
            onClick={noop}
          />
          <GroupedRow
            leading={<GroupedTile icon="hub" />}
            title="Tools"
            value="12"
            chevron={look !== "material"}
          />
          <GroupedRow
            leading={<GroupedTile icon="extension" />}
            title="Achievements"
            subtitle="Turned off on this server"
            disabled
          />
        </GroupedSection>
        <GroupedSection>
          <GroupedRow title="Remove plugin" destructive onClick={noop} chevron={false} />
        </GroupedSection>
      </>
    )}
  </Compare>
);

export const Dark = () => (
  <Compare theme="dark">
    {() => (
      <GroupedSection dividerIndent="tile">
        <GroupedRow
          leading={<GroupedTile>G</GroupedTile>}
          title="github"
          subtitle="https://api.githubcopilot.com/mcp/"
          caption="Remote · OAuth · 2 tools"
          onClick={noop}
        />
        <GroupedRow
          leading={<GroupedTile>F</GroupedTile>}
          title="filesystem"
          subtitle="npx -y @acme/mcp-fs"
          monospaceSubtitle
          warning="Sign in needed"
          value="Off"
          onClick={noop}
        />
      </GroupedSection>
    )}
  </Compare>
);
