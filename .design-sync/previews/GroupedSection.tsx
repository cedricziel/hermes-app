import {
  GroupedChoiceRow,
  GroupedListView,
  GroupedRow,
  GroupedSection,
  GroupedSwitchRow,
  GroupedTile,
  HermesProvider,
} from "@hermes-app/ui";
import type { ReactNode } from "react";

type Look = "iphone" | "mac" | "material";

const looks: Array<[Look, string]> = [
  ["iphone", "iPhone"],
  ["material", "Material"],
  ["mac", "Mac"],
];

/** iPhone and Material at phone width, the Mac at a narrow window's width. */
const frame = (look: Look) =>
  ({
    width: look === "mac" ? 520 : 390,
    border: "1px solid var(--h-border)",
    borderRadius: 14,
    overflow: "hidden",
  }) as const;

const Panel = ({
  look,
  theme = "light",
  children,
}: {
  look: Look;
  theme?: "light" | "dark";
  children: (look: Look) => ReactNode;
}) => (
  <HermesProvider
    theme={theme}
    platform={look === "material" ? "material" : "apple"}
    typeRamp={look === "mac" ? "default" : undefined}
    style={frame(look)}
  >
    <GroupedListView device={look === "mac" ? "mac" : "touch"}>
      {children(look)}
    </GroupedListView>
  </HermesProvider>
);

const Compare = ({
  theme,
  children,
}: {
  theme?: "light" | "dark";
  children: (look: Look) => ReactNode;
}) => (
  <HermesProvider
    theme={theme}
    style={{
      display: "flex",
      flexWrap: "wrap",
      gap: 8,
      padding: 8,
      width: 804,
      boxSizing: "border-box",
      alignItems: "flex-start",
    }}
  >
    {looks.map(([look]) => (
      <Panel key={look} look={look} theme={theme}>
        {children}
      </Panel>
    ))}
  </HermesProvider>
);

const noop = () => {};

const plugins = (look: Look) => (
  <GroupedSection>
    <GroupedRow
      title="netbox"
      meta="v1.2.0"
      subtitle="Query NetBox for devices and prefixes."
      value="On"
      chevron={look !== "material"}
      onClick={noop}
    />
    <GroupedRow
      title="notes-sync"
      meta="v1.2.0"
      subtitle="Keep a folder of notes in step with memory."
      value="Off"
      chevron={look !== "material"}
      selected={look === "mac"}
      onClick={noop}
    />
    <GroupedRow
      title="calendar"
      meta="v1.2.0"
      subtitle="Read and create calendar events."
      value="Inactive"
      warning="Needs login"
      chevron={look !== "material"}
      onClick={noop}
    />
    <GroupedRow
      title="terminal"
      meta="v1.2.0"
      subtitle="Bundled · Run shell commands."
      value="On"
      chevron={look !== "material"}
      onClick={noop}
    />
  </GroupedSection>
);

/** Plugins' Installed list: version as meta, status as a muted value with a chevron (Material: no chevron), "Needs login" as the warning line; the Mac highlights the row shown beside the list. */
export const StatusRows = () => <Compare>{plugins}</Compare>;

/** A Skills category: a header over switch rows (the small toggle on a Mac), then "Check for updates" as a single-row group with a footer. */
export const SwitchRows = () => (
  <Compare>
    {(look) => (
      <>
        <GroupedSection header="DevOps">
          <GroupedSwitchRow
            title="docker-compose"
            subtitle="Run and inspect compose stacks · Bundled"
            checked
            onChange={noop}
          />
          <GroupedSwitchRow
            title="k8s-logs"
            subtitle="Tail pod logs · Hub · used 12 times"
            checked={false}
            onChange={noop}
          />
        </GroupedSection>
        <GroupedSection footer="Hub skills update from the skills hub.">
          <GroupedRow
            title="Check for updates"
            icon={look === "material" ? "refresh" : undefined}
            onClick={noop}
            chevron={false}
          />
        </GroupedSection>
      </>
    )}
  </Compare>
);

/** Messaging and MCP rows: leading tiles (icon or letter) with separators past them, a mono command, a caption, an error and a warning line, and a "Set Up" value. */
export const TilesCaptionsErrors = () => (
  <Compare>
    {() => (
      <>
        <GroupedSection
          dividerIndent="tile"
          footer="Connect Hermes to Telegram, Discord, and other messaging platforms."
        >
          <GroupedSwitchRow
            title="Telegram"
            leading={<GroupedTile icon="smart_toy" />}
            checked
            onChange={noop}
          />
          <GroupedSwitchRow
            title="Discord"
            leading={<GroupedTile icon="smart_toy" />}
            error="Invalid bot token"
            checked={false}
            onChange={noop}
          />
          <GroupedRow
            title="Slack"
            leading={<GroupedTile icon="smart_toy" />}
            value="Set Up"
            onClick={noop}
          />
        </GroupedSection>
        <GroupedSection header="Servers" dividerIndent="tile">
          <GroupedSwitchRow
            title="github"
            leading={<GroupedTile>G</GroupedTile>}
            subtitle="https://api.githubcopilot.com/mcp/"
            caption="Remote · OAuth · 2 tools"
            checked
            onChange={noop}
            onClick={noop}
          />
          <GroupedSwitchRow
            title="filesystem"
            leading={<GroupedTile>F</GroupedTile>}
            subtitle="npx -y @acme/mcp-fs ~/notes"
            monospaceSubtitle
            warning="Sign in needed"
            checked={false}
            onChange={noop}
            onClick={noop}
          />
        </GroupedSection>
      </>
    )}
  </Compare>
);

/** Plugins' memory provider: a check mark on the picked row on Apple, radio buttons on Material; an unavailable provider is dimmed with a warning. */
export const ChoiceRows = () => (
  <Compare>
    {() => (
      <GroupedSection
        header="Memory provider"
        footer="Where the agent keeps long-term memory."
        dividerIndent="choice"
      >
        <GroupedChoiceRow title="Built-in" subtitle="No external memory" />
        <GroupedChoiceRow
          title="holographic"
          meta="Ready"
          subtitle="Remembers things with holographic."
          checked
        />
        <GroupedChoiceRow
          title="vector-store"
          subtitle="Remembers things with vector-store."
          warning="Unavailable"
          disabled
        />
      </GroupedSection>
    )}
  </Compare>
);

export const Dark = () => (
  <Compare theme="dark">
    {(look) => (
      <>
        {plugins(look)}
        <GroupedSection header="Context engine" dividerIndent="choice">
          <GroupedChoiceRow
            title="compressor"
            subtitle="Summarises old turns."
            checked
          />
          <GroupedChoiceRow
            title="sliding-window"
            subtitle="Keeps the last turns."
          />
        </GroupedSection>
      </>
    )}
  </Compare>
);
